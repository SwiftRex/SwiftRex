# Migrating to ViewStore and StateStream

Move an app from the whole-state view stores (`@Feature(strategy: .observationSimple)`, the `ViewStore` class, `@Tracked`, bindings on any store) to granular `ViewStore` reads and declarative stores — step by step, mechanically, and without the traps we hit doing it.

## Overview

This guide migrates code written before granular observation — `@Feature(strategy: .observationSimple | .observationGranular | .combineObservable)`, the `ViewStore<ViewState, ViewAction>` class, `TrackedViewStore` / `@Tracked`, `ObservableObjectStore`, `store.state`, `store.observe(didChange:)`, `store.publisher`, `store.stream`, and bindings or presentation helpers called on any store — to the current API. It was written while migrating the SwiftRexNavGallery sample (every navigation container; 18 source files, 53 lines added and 78 removed), so every step below is one that app needed.

Work top to bottom: each step makes the next step's compiler errors meaningful. Build after every step (`swift build 2>&1 | xcsift`), and let the compiler's error locations — not a search — decide what to rewrite.

## The one mental shift

**A store can't be read anymore; only a `ViewStore` can.** ``StoreType`` is `dispatch` plus a ``StoreType/stateStream`` you follow. There is no `store.state` and no `observe(didChange:)`. A SwiftUI view reads through a `ViewStore`, and `viewStore.state` is not the state value — it is a *position* in it:

```swift
viewStore.state.title // String — a leaf comes back as the value (and depends on \.title only)
viewStore.state.player // GranularTracking<Player> — a position you keep reading into
viewStore.state.player.value // the whole Player — a coarse read, depends on \.player
```

The same rule, one level up: **only a `ViewStore` reads, and every view store has one owner.** Anything you derive — a projection, a transposed optional, a collection element — is a pure stage with no state to read; a child observes it through its own view store, kept by the child.

That one fact explains most compiler errors below. Old code where `viewStore.state.title` was a plain read keeps compiling (now granular). Old code that *used* `viewStore.state.x` as a value — `ForEach(viewStore.state.items)`, `.detail(for: viewStore.state.selection)`, `.dispatch(.open(viewStore.state.item))` — doesn't, because `x` is now a position.

## Step 1 — Macros: drop the strategy arguments

| Before | After |
|---|---|
| `@Feature(strategy: .observationSimple)` / `.observationGranular` | `@Feature` |
| `@Feature(strategy: .combineObservable)` | `@Feature(strategy: .combine)` |
| `@BoundTo(X.self, strategy: …)` | `@BoundTo(X.self)` |
| `@Tracked`, `TrackedViewStore`, hand-built split view stores | delete — reads are granular already |

Safe rewrite (regex, whole tree):

```
@Feature\(strategy: \.observation(Simple|Granular)\)   →  @Feature
@Feature\(strategy: \.combineObservable\)              →  @Feature(strategy: .combine)
@BoundTo\((\w+)\.self, strategy: \.\w+\)               →  @BoundTo(\1.self)
```

## Step 2 — Drop the iOS 17 gates added for the old view stores

Only code that uses the Observation framework is availability-gated now; views, routers and `Feature` conformances are not. Remove `@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)` from **views, view structs, routers and `extension X: Feature {}`**. Keep it on code that calls Observation directly (`withObservationTracking`, `@Observable`).

> Warning: Leaving one behind fails only on a platform whose deployment target is below the gate — typically **iOS 16** — so a macOS-only build (or CI) passes and the iOS build fails: `'RDetailView' is only available in iOS 17 or newer`. Build for the iOS simulator before calling the migration done.

## Step 3 — `ViewStore` generic order and ownership

The old `ViewStore<ViewState, ViewAction>` was a class you could build anywhere. The new `ViewStore<Action, State>` is a struct you **receive**; an **owner** builds it once.

| Before | After |
|---|---|
| `ViewStore<X.State, X.Action>` (state first) | `ViewStore<X.Action, X.State>` (action first) |
| `let viewStore: ViewStore<…>` in a receiver view | unchanged — receivers stay a plain `let` |
| `viewStore = ViewStore(store)` in a view's `init` | `@OwnedStore var viewStore: ViewStore<A, S>` + `_viewStore = OwnedStore(wrappedValue: store.viewStore())` |
| same, where `store` is `any StoreType<A, S>` | `_viewStore = OwnedStore(wrappedValue: store.viewStore())` (an existential makes one the same way) |
| `Root(viewStore: ViewStore(store), …)` in a hand-written `view(store:environment:)` | `Root(store: store, …)`, where `Root` keeps `@OwnedStore var viewStore` made from it in `init` |
| `store.observable()` / `asObservableObject()` | `store.viewStore(.combine)`, kept by `@OwnedStore` |
| the `App` holding the store in `@StateObject` / an observable wrapper | the `App` keeps the real `Store` as a plain `let` (deep links and scene code dispatch to it); the root view keeps `@OwnedStore` made from `store.viewStore()` |

Making a view store is always explicit — `.viewStore()` (or `.viewStore(.combine)`), a method on every store: a `Store`, a projection, a buffer, a derived stage, an `any StoreType<A, S>`. `@OwnedStore` only keeps the `ViewStore` it is given; it never holds a `Store`, and never takes a strategy. Never call `.viewStore()` bare in a `body` — that makes a new view store every render.

Safe rewrites:

```
ViewStore<(\w+)\.State, (\w+)\.Action>                              →  ViewStore<\2.Action, \1.State>
(\w+)\(viewStore: ViewStore\(store\), environment: environment\)   →  \1(store: store, environment: environment)
```

> Warning: The generic-order swap is **not idempotent**. `ViewStore<AppState, AppAction>` (no `.State` / `.Action` suffix) isn't matched by the pattern and has to be swapped by hand — and running any "swap the two arguments" rule over already-migrated code swaps them back. Run it once, on old code only.

## Step 4 — Bindings: one name, one chained scope

Every binding is `binding(_:)` taking one chained scope — a `.state(…)` lane and an `.action(…)` lane. What the action lane carries decides the kind:

| Before | After |
|---|---|
| `binding(.state(\.x), dispatch: .action(\.setX))` | `binding(.state(\.x).action(\.setX))` → `Binding<X>` |
| `presence(.state(\.x), dismiss: .closeX)` | `binding(.state(\.x).action(\.closeX))` → `Binding<Bool>` (a no-payload case) |
| `item(.state(\.x), dismiss: .closeX)` | `binding(.state(\.x).action(\.closeX))` → `Binding<X?>` |
| `presenting(store, \.slot, dismiss: .slot(.dismiss)) { … }` | `.sheet(item: viewStore.binding(.state(\.slot).action(\.slot))) { … }` |
| `presentingItem(…)` | the same `.sheet(item:)` |

SwiftUI's parameter picks the binding type: `.sheet(isPresented:)` gets the `Bool`, `.sheet(item:)` the optional. Bindings exist only on `ViewStore` — a binding on a plain `Store` or `StoreProjection` no longer compiles (it never updated a view).

`Presentation` slots: the action lane is the slot's `PresentationAction`, which now has two dismissal cases — `.dismiss` when a dismissal starts, `.dismissed` when SwiftUI's animation ends. Reducers that handled `.dismiss` twice (`presented → dismissing → dismissed`) handle `.dismissed` for the second step (`liftPresentation(action:state:environment:)` does it for you). For containers other than `.sheet(item:)`, take the binding's parts: `.fullScreenCover(isPresented: b.isPresented(), onDismiss: b.onDismiss())`.

Safe rewrites (these **must** be paren-aware — see *Pitfalls*):

```
.binding(.state(X), dispatch: Y)   →  .binding(.state(X)Y)
.presence(.state(X), dismiss: .c)  →  .binding(.state(X).action(\.c))
.item(.state(X), dismiss: .c)      →  .binding(.state(X).action(\.c))
```

## Step 5 — Reads that need a value

After steps 1–4, the remaining errors are almost all the mental shift. Fix each at the compiler's location:

| Before | After |
|---|---|
| `ForEach(viewStore.state.items) { item in …(item)… }` | `ForEach(viewStore.state.each(\.items)) { item in …(item.value)… }` — `item.title` field reads stay as they are |
| `f(viewStore.state.selection)` — a non-leaf passed as a value | `f(viewStore.state.selection.value)` |
| `node.unwrapped()` | `node.transpose()` |
| `viewStore.peek(\.x)` inside an action closure | dispatch the intent instead (`.markAtPlayhead`); the reducer has the state |
| `viewStore.read(\.x)` for a shadowed member | `viewStore.state[dynamicMember: \.x]` |

## Step 6 — Optional children and routers

| Before | After |
|---|---|
| `store.projection(…).transpose()` in a body or router | `viewStore.traverse(.action(\.x).state(\.x))` (key paths) or `viewStore.traverse(action: …, state: …)` (closure lane) |
| a view store whose own state is `T?` / `Presentation<T>`, unwrapped | `viewStore.transpose()` (no arguments) |
| `ForEach` of rows built with a projection by id | `ForEach(viewStore.each(.action(\.row).state(\.rows))) { RowView(store: $0) }` — display-only rows: `viewStore.state.each(\.rows)` |
| one element outside a loop, by id | `viewStore.traverse(.action(\.row).state(\.rows), element: id)` |
| a child view taking a slice it dispatches into | `Child(store: viewStore.projection(.action(\.x).state(\.x)))`, the child keeping `.viewStore()` of it with `@OwnedStore` |
| a router holding `any StoreType<…>` / `MainStoreType` | a router holding the app's `ViewStore<AppAction, AppState>` |
| `store.projection(…).transpose()` outside SwiftUI (UIKit) | follow presence as state: `store.stateStream.map { $0.x != nil }.removeDuplicates().observe { … }` |

A child view that keeps its own view store over a stage it is handed:

```swift
struct DetailView: View {
    @OwnedStore var viewStore: ViewStore<DetailAction, Detail>
    init(store: some StoreType<DetailAction, Detail>) { _viewStore = OwnedStore(wrappedValue: store.viewStore()) }
    var body: some View { … }
}
```

**Pure until the leaf.** Everything derived — a projection, a transposed slot, an element — is a pure stage: it follows a stream and has no state to read. A child observes it through its **own** view store, kept by the view that uses it: `@OwnedStore var viewStore` made from the stage (`store.viewStore()`) in that view's `init` — a feature's `view(store:environment:)` does it for you. The parent keeps nothing for its children, and a child redraws only for what it reads.

## Step 7 — Code outside SwiftUI

| Before | After |
|---|---|
| `store.state` | follow `store.stateStream`; in tests, `TestStore.state` (still readable) |
| `store.observe(didChange: { … store.state … })` | `store.stateStream.observe { state in … }` — delivers the current state at once, then each change |
| `store.publisher` (Combine) | `store.stateStream` — it **is** a `Publisher` |
| `store.publisher` (ReactiveConcurrency) | `store.stateStream.asPublisher` |
| `store.stream()` | `for await state in store.stateStream` |
| `SubscriptionToken` from `observe` | ``UISubscriptionToken`` — keep it; releasing it stops delivery |

## Coming from an intermediate version

If you already moved to an earlier cut of this API, these names are gone:

| Intermediate | Current |
|---|---|
| `ProjectionKeeper` (a body keeping a child's projection) | hand the pure stage to a child view; the child keeps its own `@OwnedStore` view store |
| `@OwnedStore var viewStore = store` / `OwnedStore(store)` (a `Store` in the wrapper) | `@OwnedStore var viewStore = store.viewStore()` / `OwnedStore(wrappedValue: store.viewStore())` |
| `@OwnedStore(.combine)` / `OwnedStore(wrappedValue: s, .combine)` | `OwnedStore(wrappedValue: s.viewStore(.combine))` — the strategy goes where the view store is made |
| `viewStore.focus(…)` | `viewStore.projection(scope)` for a slice, `viewStore.traverse(scope)` for an optional, `viewStore.each(scope)` / `traverse(scope, element:)` for elements |
| `viewStore.transpose(scope)` (with arguments) | `viewStore.traverse(scope)`; `transpose()` takes no arguments |
| `StoreElement` / `StoreUnwrap` | ``StoreCollectionFocus`` / ``StoreOptionalFocus`` |

## Symptoms → fixes

| Compiler says | It means | Fix |
|---|---|---|
| `type 'ViewStrategy' has no member 'observationSimple'` | old `@Feature` strategy | step 1 |
| `extra argument 'strategy' in macro expansion` | old `@BoundTo` strategy | step 1 |
| `cannot find 'viewStore' in scope` (in a `@BoundTo` view) | knock-on of the macro error above | step 1, then rebuild |
| `'X' is only available in iOS 17 or newer` | a stale gate | step 2 |
| `cannot convert value of type 'Feature.State' to expected argument type 'Feature.Action'` | old generic order | step 3 |
| `'ViewStore<Action, State>' initializer is inaccessible` | `ViewStore(store)` built by hand | step 3 — an owner |
| `extra argument 'dispatch' in call` / `extra argument 'dismiss'` / `has no member 'presence'` | old binding shape | step 4 |
| `generic parameter 'A' could not be inferred` on a binding | an untyped closure lane | pitfall 6 |
| `'subscript(dynamicMember:)' is unavailable: a state collection is a position, not a collection …` | `ForEach` over a position | step 5 — `each(\.items)` (older SwiftRex said `requires that 'X' conform to 'IndivisibleTracking'`) |
| `… on 'Optional' requires that 'X' conform to 'IndivisibleTracking'` | a non-leaf position passed as a value | step 5 — `.value` |
| `value of type 'StoreProjection<…>' has no member 'transpose'` | core transpose is gone | step 6 |
| `value of type 'ViewStore<…>' has no member 'focus'` | children are derived and owned | step 6 — `projection(scope)` / `traverse(scope)`, owned by the child |
| `value of type 'StoreOptionalFocus<…>' has no member 'state'` / `'binding'` | a derived stage used as a view store | hand it to a child that keeps `@OwnedStore var viewStore` made from it, or to the child feature's view |
| `cannot find 'ProjectionKeeper' in scope` | the keeper is gone | *Coming from an intermediate version* |
| `cannot convert value of type 'Store<…>' to expected argument type 'ViewStore<…>'` on `@OwnedStore` | a store put in the wrapper | `.viewStore()` it first |
| `'state' is inaccessible due to 'private' protection level` | reading a `Store` | step 7 |

## Pitfalls — learned doing this

These all happened while building this API or migrating the sample app. Each one cost a build-and-read cycle; a mechanical migration avoids them.

1. **Rewrite by compiler error location, never by search.** A global "`x.state` → something" rewrite also hit values that merely have a `state`-named member, and a script that rewrote `ScreenAction.transport` into `ScreenAction.state.transport` produced code that compiled into nonsense. Take the file and line from the error, and rewrite only there.
2. **`sed` can't rewrite nested calls.** `binding(.state(\.x), dispatch: .action(review: { .set($0) }))` has parentheses inside the arguments; a regex over `\([^)]*\)` stops at the first `)`. Use a paren-balancing rewrite (split arguments at depth 1, skipping string literals), or do these by hand.
3. **A regex that anchors on `.binding(` misses bare mentions.** Prose and tables write `binding(…)` without the leading dot. Run the rewrite a second time with a pattern that doesn't require the dot (and doesn't match inside a longer identifier: `(?<![.\w])binding\(`).
4. **Substring checks lie.** An assertion that `store.state` no longer appears also matches `store.stateStream`. Check with a word boundary or the compiler, not a substring.
5. **Mind the platform and trait guards when appending code.** Appending a test suite or helper after a file's closing `#endif` compiles it on every platform — it built on macOS and broke Linux CI (`unknown attribute 'Suite'`). Insert *before* the guard's `#endif`.
6. **Type closure action lanes.** In a chained optional scope, `.action(review: { _ in .close })` is ambiguous (`generic parameter 'A' could not be inferred`). Use a key path (`.action(\.close)`) or type the parameter: `{ (_: Void) in .close }`.
7. **Don't commit what a trait-less build resolved.** `xcodebuild` — and a plain `swift build` without `--enable-all-traits` — enables no package traits, so it re-resolves `Package.resolved` **without** the trait-gated dependencies (ReactiveConcurrency, RxSwift, ReactiveSwift). Restore the file before committing. Likewise, a local `.package(path:)` used to test against an unreleased SwiftRex rewrites `Package.resolved` — never commit either.
8. **Deleting a hand-written block by slicing to a marker takes its neighbours with it.** Cutting "from this comment to `#endif`" also deleted an `Equatable` conformance that sat below the block. Review the diff of every scripted deletion.
9. **Build for iOS, not just macOS.** Stale iOS 17 gates (step 2) and Linux-only guards pass a macOS build. Build the iOS simulator target before calling it done.
10. **A first-launch screenshot can be blank.** The first frame of a freshly installed app takes a few seconds; a blank white screen right after `simctl launch` is not a rendering bug — capture again before investigating.
11. **A tap that does nothing: read the action log before blaming the store.** Log every action and the state it produced (a DEBUG-only `produce` behavior, first in the app's fold). No action after the gesture means SwiftUI never wrote its binding — a view wiring problem; an action with unchanged state means the reducer or lift; new state with no redraw means the view reads a different path. The NavGallery Split tab looked like a SwiftRex regression and was neither: see the next pitfall.
12. **`List(selection:)` rows on iPhone must be `NavigationLink(value:)`.** A `.tag(…)`ged row selects on tap on iPad and Mac but, on iPhone (compact width), only in edit mode — so a `NavigationSplitView` sidebar of tagged rows does nothing on a phone, before and after migrating. Use `NavigationLink(item.title, value: Selection.item(item.value))` rows.
13. **SwiftUI may write a binding twice for one gesture** (a list row tap writes its selection twice). A two-way `binding` over an `Equatable` value drops a write equal to the current value, so the reducer sees one action; for a non-`Equatable` value, make the reducer idempotent.
14. **Fixed sleeps in tests flake under load.** A test that sleeps 50 ms and expects a value fails when the whole suite starts together: hundreds of main-actor tests queue at once, and any hop to the main actor waits ~250 ms. Poll with a bounded wait instead.

## A worked example

The SwiftRexNavGallery migration, in the order above:

1. `@Feature(strategy: .observationSimple)` → `@Feature` (6 modules), `@BoundTo(…, strategy:)` → `@BoundTo(…)` (6 views).
2. 26 `@available(iOS 17, …)` gates removed from views, routers and `Feature` conformances.
3. `ViewStore<X.State, X.Action>` → `ViewStore<X.Action, X.State>` (4 container views by regex, 3 `ViewStore<AppState, AppAction>` by hand); four hand-written `view(store:environment:)` → a root view keeping `@OwnedStore` made from `store.viewStore()`; the app root → `@OwnedStore` with `OwnedStore(wrappedValue: store.viewStore())`.
4. Twelve binding call sites → `binding(.state(…).action(…))`: six former `presence` (two of them the iOS / macOS branches of one cover) and six `binding(…, dispatch:)`.
5. Five `ForEach(viewStore.state.xs)` → `each(\.xs)` with `.value` where the element is dispatched; one `.value` on a selection passed to a router.
6. The router holds the app `ViewStore`; three `store.projection(…).transpose()` → `viewStore.traverse(action:state:)`, each handing the stage to a child view that keeps its own view store.

## See Also

- <doc:StoresAtAGlance>
- <doc:ObservingInSwiftUI>
- <doc:Features>
- <doc:Navigation>
