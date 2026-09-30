# Features with @Feature

Co-locate a whole feature — state, actions, behavior, and its SwiftUI screen — in one `enum`, and climb from the leanest possible feature to a full module one concern at a time.

## Overview

`SwiftRex.Architecture` is the opinionated layer on top of `SwiftRex.SwiftUI`. Where <doc:BuildYourFirstFeature> wires a `Store`, a `Behavior`, and a view by hand, `@Feature` folds that wiring into a single `enum` namespace: you describe the feature, and the macro synthesizes `initialState(with:)` and an erased `view(store:environment:) -> some View`, applies `@ApplyOptics(recursively: true)` to `State`, `Action`, and any other nested domain type — `@Lenses` for structs, `@Prisms` for enums, recursively down the whole nested tree — and hands `Content` a `ViewStore` that redraws only what changed. (State you declare in an *extension* of the feature isn't visible to the macro: annotate that extension with `@ApplyOptics(recursively: true)` yourself.)

`@Feature` takes one optional knob:

- **`strategy:`** — a `ViewStrategy`, how the view store signals SwiftUI. `.automatic` (the default) uses the Observation framework on iOS 17+ and a Combine signal below; `.combine` forces Combine everywhere. Nothing is availability-gated and the view never changes — see "L3 — observation and composition" below.

**Access follows the `enum`'s own modifier** — exactly like `@BoundTo`. A `public enum` is a module's public entry: the generated `view()`/`initialState(with:)` are `public`, so the composing app can render and seed it (declare its `State`/`Action`/`Environment`/`Input` `public` too, so they can be lifted). A plain `enum` is a screen composed *inside* a module — its generated members stay `internal`. There is no `type:` argument; the declaration says it.

**The `Feature` conformance is generated too.** A feature that builds a view (it has a `Content`, or a hand-written `view`) conforms to ``Feature`` — you never write `extension X: Feature {}` by hand. A view-less feature is a behavior only: it gets no `Feature` conformance, and (it already has `behavior()`) declares `: HasBehavior` itself in one line on the rare occasion it must be used through that protocol.

The paired SwiftUI view carries `@BoundTo(Feature.self)`, which injects `let viewStore: ViewStore<ViewAction, ViewState>` — a plain-`let` receiver under every strategy (the generated `view()` owns the store). The view body is the same under every strategy — `viewStore.<field>` to read (granular: the view depends on that path only), `viewStore.dispatch(.<action>)` to send.

This article is the full L0→L4 progression; the [README](https://github.com/SwiftRex/SwiftRex#readme) shows the condensed form — one feature in one screen.

> `@Feature` requires a **Swift 6.3+** toolchain. The macro is not availability-gated, so a `.combine` feature builds to the package floor (iOS 16, macOS 13, tvOS 16, watchOS 9); on Linux/Windows/Android the whole SwiftUI/Observation layer compiles out.

## What the macro needs

Some nested members are required; the rest the macro synthesizes when omitted:

| Member | Required? | Omitted ⇒ |
|---|---|---|
| `struct State` | ✅ (gets `@Lenses`) | — |
| `enum Action` | ✅ (gets `@Prisms`) | — |
| `static func behavior() -> Behavior<Action, State, Environment>` | ✅ | — |
| `typealias Content = SomeView` | to get a `view()` and `: Feature` | logic-only feature — no `view()`, no `: Feature` conformance |
| `struct Environment` | optional | aliased to `Void` |
| `struct ViewState` | optional | aliased to `= State` |
| `enum ViewAction` | optional | aliased to `= Action` |
| `static let mapState` / `mapAction` | only with a declared `ViewState`/`ViewAction` | no projection — `view()` wraps the store directly |
| `typealias Input` | optional | `initialState(with:)` seeds from `State.init()` |

The view projection layer is **optional**. Omit `ViewState`/`ViewAction`/`mapState`/`mapAction` and the macro aliases `ViewState = State`, `ViewAction = Action`, and the generated `view()` wraps the store directly — the view reads the domain types. Declare a distinct `ViewState` only when the UI needs a different shape.

## L0 — the leanest feature

`State`, `Action`, `behavior()`, and a `Content` view. No `Environment` (aliased to `Void`), no view projection.

```swift
@Feature
enum Counter {
    struct State: Sendable, Equatable { var count = 0 }
    enum Action: Sendable { case tick }

    static func behavior() -> Behavior<Action, State, Environment> {
        .reduce { action, state in
            switch action {
            case .tick: state.count += 1
            }
        }
    }

    typealias Content = CounterView
}

@BoundTo(Counter.self)
struct CounterView: View {
    // injected: let viewStore: ViewStore<Counter.ViewAction, Counter.ViewState> (aliases of Action/State here)
    var body: some View {
        Button("count: \(viewStore.count)") { viewStore.dispatch(.tick) }
    }
}
```

## L1 — add dependencies

Declare an `Environment` so effects can reach a client, a clock, or a `now` function. The behavior's third generic picks it up; nothing else about the feature changes.

```swift
struct Environment: Sendable {
    var now: @Sendable () -> Date
}
```

Inside the behavior, an effect reads `ctx.environment` in phase 3 — see <doc:AddingEffects>. Keeping the dependency in the `Environment` (rather than reaching for an ambient `Date()`) is what makes the feature testable with a stub.

## L2 — a distinct view shape

When the UI needs a shape the domain doesn't have — an `Int` shown as a `String`, a joined list bound to a `TextField` — declare `ViewState`/`ViewAction` and the two maps. Each map is a `Reader<Environment, …>`, so it can format and parse with live dependencies. `mapAction` parses raw view input back into a domain `Action`.

```swift
@Feature
enum HeroDetails {
    struct State: Sendable {
        var codename = "Kryptonian"
        var aliases  = ["Superman", "Man of Steel"]
        var powers   = ["flight", "heat vision"]
        var isRetired = false
    }

    enum Action: Sendable, Equatable {
        case savePowers([String])
        case toggleRetirement
    }

    struct Environment: Sendable {}

    struct ViewState: Sendable, Equatable {
        var displayName: String   // aliases.first ?? codename
        var powersText: String    // joined for the TextField
        var isRetired: Bool
    }

    enum ViewAction: Sendable {
        case editedPowers(String) // raw comma-separated TextField content
        case tappedRetirement
    }

    static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { _ in
        { s in
            .init(
                displayName: s.aliases.first ?? s.codename,
                powersText: s.powers.joined(separator: ", "),
                isRetired: s.isRetired
            )
        }
    }

    static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action> { _ in
        { va in
            switch va {
            case .editedPowers(let raw):
                .savePowers(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            case .tappedRetirement:
                .toggleRetirement
            }
        }
    }

    static func behavior() -> Behavior<Action, State, Environment> {
        .reduce { action, state in
            switch action {
            case .savePowers(let p): state.powers = p
            case .toggleRetirement:  state.isRetired.toggle()
            }
        }
    }

    typealias Content = HeroDetailsView
}
```

The binding and presentation helpers live on the `ViewStore`, so they work straight off the `viewStore` — including two-way `binding`s whose write dispatches a `ViewAction`. (They don't exist on a plain `Store` or `StoreProjection`: a binding SwiftUI can't observe would never update, so it doesn't compile.)

```swift
@BoundTo(HeroDetails.self)
struct HeroDetailsView: View {
    // injected: let viewStore: ViewStore<HeroDetails.ViewAction, HeroDetails.ViewState>
    var body: some View {
        Form {
            Text(viewStore.state.displayName).font(.headline)
            // `.action(review:)` takes `(Value) -> ViewAction`, so pass the case constructor directly:
            TextField("Powers", text: viewStore.binding(.state(\.powersText).action(review: HeroDetails.ViewAction.editedPowers)))
            Toggle("Retired", isOn: viewStore.binding(.state(\.isRetired).action(\.tappedRetirement)))
        }
    }
}
```

`binding` takes an axis pair — a `.state(…)` lane that *reads* the slice and a `.action(…)` lane that
*embeds* the same value type — coupling into a `Binding` of that value. The slots are typed so they can't
be crossed, and each offers only its own strategies (`\.case` / prism / `review:` for the action, key
path / closure for the state):

```swift
TextField("Powers", text: viewStore.binding(.state(\.powersText).action(\.editedPowers)))
```

## L3 — observation and composition

A view reads its store **granularly**: `viewStore.state.title` records a dependency on `\.title` alone, and the view redraws only when that value changes (compared with `==`, as `@Observable` does). State stays a plain struct where it lives — nothing is copied into a class.

The walk goes as deep as you read. A member whose type is `IndivisibleTracking` (strings, numbers, `Bool`, `Date`, `UUID`, `URL`, `Data`, optionals and arrays of those…) comes back as the value; anything else comes back as a `GranularTracking` position you keep reading into:

```swift
Text(viewStore.state.transport.position, format: .number)   // depends on \.transport.position only
viewStore.state.transport                                   // a GranularTracking<Transport>
viewStore.state.transport.value                             // the whole Transport — depends on \.transport
extension Status: IndivisibleTracking {}                    // opt a type in to be read whole
```

**Pass positions, not values, to subviews.** The child then depends only on what *it* reads, so a hot field redraws the one view that shows it:

```swift
struct PlayerScreen: View {
    let viewStore: ViewStore<Player.ViewAction, Player.ViewState>
    var body: some View {
        Console(mixer: viewStore.state.mixer)            // never redraws on playhead ticks
        Playhead(transport: viewStore.state.transport)   // redraws 10× a second, alone
    }
}
```

For lists, `each` gives one position per `Identifiable` element — the list depends on the ids (insert / remove / reorder), each row on its own element:

```swift
List(viewStore.state.each(\.songs)) { song in SongRow(song: song) }
```

A subview that needs to send actions or build bindings takes a **focused** view store — a key-path slice read through the same snapshot, with its own action lane (no new subscription): `viewStore.focus(.action(\.transport).state(\.transport))`.

### Composing projection, buffer and the view store

Three stages, one job each — each follows the one below through its `stateStream`:

| Stage | Does | Costs per upstream change |
|---|---|---|
| `projection(action:state:)` | narrows types; keeps nothing | the map, once per observer |
| `buffer()` | passes changes on only when `!=` | one `==` |
| the view store | keeps a snapshot, signals SwiftUI per changed dependency | the changed dependencies |

The view store already *is* the buffer after the map — it only signals what changed — so the one placement decision left is **before** the map: `store.buffer().projection(…)` skips the map entirely when the input didn't change. `@Feature`'s generated view does exactly that when the feature's `State` is `Equatable` (`buffer → projection → view store`).

Focusing stays on the same view store only through key paths (`focus`): a projection through a closure can't be seen into, so it returns a plain `StoreProjection`, which gets its own view store from an owner (`@OwnedStore`, `ProjectionKeeper`). A view store only passes a state on when its snapshot changed, so a store projected from it is woken only by changes that reached it.

### Owners, receivers and strategies

> Note: Wiring views without `@Feature`? <doc:ObservingInSwiftUI> covers every owner / receiver / projection / strategy combination, and <doc:StoresAtAGlance> maps every store type and shows exactly which views redraw under Observation vs Combine.

The view store is built **once**, by its owner, and handed down: the owner is `@Feature`'s generated view, or `@OwnedStore var viewStore = appStore` in a view you write (its initial value is lazy, like `@StateObject`'s, so re-creating the view never rebuilds it); every view below takes `let viewStore: ViewStore<…>`.

The strategy is chosen by the owner and changes only how the store signals SwiftUI — receivers and bodies are identical:

```swift
@Feature(strategy: .combine)                 // force Combine, even on iOS 17+
enum Widget { … }

@BoundTo(Widget.self)                        // injects `let viewStore: ViewStore<…>` — no strategy here
struct WidgetView: View {
    var body: some View { Text(viewStore.state.label) }
}

@OwnedStore(.combine) var viewStore = appStore   // the same override on a hand-written owner
```

Under Observation (the `.automatic` default on iOS 17+) only the views that read a changed path redraw. Combine can't be per view — `ObservableObject` has one signal — but it's still sent only when a path some view read has changed, so unrelated state changes redraw nothing.

A `ViewState` is never needed for performance; declare one only when the UI wants a different shape. A `State` member whose name clashes with a position member (`value`, `each`, `id`, …) is shadowed — read it with `viewStore.state[dynamicMember: \.value]`.

## L4 — a full module

A `public enum` module entry point is the only thing a composing app sees of a module. Its `State`/`Action`/`Environment`/`Input` are `public` (they must be liftable), and — because access follows the `enum` — so are the generated `view(store:environment:)` and `initialState(with:)`. It adds a seed (`Input`), an effect through the behavior, and state-driven navigation.

```swift
@Feature
public enum Library {
    public struct Input: Sendable { public var shelfID: String }

    public struct State: Sendable, Equatable {
        var shelfID: String
        var isLoading = false
        var books: [Book] = []
        var selected: Book?        // non-nil ⇒ present the detail sheet
    }

    public enum Action: Sendable {
        case onAppear
        case loaded([Book])
        case tapped(Book)
        case dismissedDetail
    }

    public struct Environment: Sendable {
        public var fetch: @Sendable (String) async -> [Book]
    }

    // Seed the initial state from the Input handed in by the composing app.
    public static func initialState(with input: Input) -> State { .init(shelfID: input.shelfID) }

    // `Effect.task` comes from `SwiftRex.SwiftConcurrency` — `import SwiftRexSwiftConcurrency`.
    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, _ in
            switch action {
            case .onAppear:
                .reduce { $0.isLoading = true }
                .produce { ctx in
                    Effect.task {
                        let shelf = await ctx.liveState?.shelfID ?? ""
                        return .loaded(await ctx.environment.fetch(shelf))
                    }
                }
            case .loaded(let books):
                .reduce { $0.books = books; $0.isLoading = false }
            case .tapped(let book):
                .reduce { $0.selected = book }
            case .dismissedDetail:
                .reduce { $0.selected = nil }
            }
        }
    }

    typealias Content = LibraryView
}
```

Navigation is state-driven: the `Binding<Book?>` from `binding(.state(\.selected).action(\.dismissedDetail))` presents while `selected` is `.some` and only ever dispatches the *dismiss* action when SwiftUI clears it — presentation is always a function of state, never driven by the binding. The sibling `presence` binding does the same for `.sheet(isPresented:)`.

```swift
@BoundTo(Library.self)
struct LibraryView: View {
    // injected: let viewStore: ViewStore<Library.ViewAction, Library.ViewState> (aliases of Action/State here)
    var body: some View {
        List(viewStore.state.each(\.books)) { book in
            Button(book.title) { viewStore.dispatch(.tapped(book.value)) }
        }
        .onAppear { viewStore.dispatch(.onAppear) }
        .sheet(item: viewStore.binding(.state(\.selected).action(\.dismissedDetail))) { book in
            Text(book.title)
        }
    }
}
```

## Composing modules into the app

The app lifts each feature's `behavior()` into the parent store and renders it through the erased `view()`. A whole child module lifts through a ``Relay/Scope`` (`.action(…).state(…).environment(…)`); an *optional* child screen uses an optional state key path (an **affine** state lane — it runs only while the sub-state is `.some`); a collection of children through `liftCollection` — see <doc:Lifting> and <doc:Modularisation>.

```swift
// Declared scopes — `ScopeOf<AppFeature>` pins the app triad, so every root infers.
let library = ScopeOf<AppFeature>
    .action(\.library)                       // a `\.case` prism — Prism<AppAction, Library.Action>
    .state(\.library)                        // total WritableKeyPath → ReadsWrites lane
    .environment { $0.library }
let heroDetail = ScopeOf<AppFeature>
    .action(\.heroDetail)
    .state(\.heroDetail)                     // optional key path → affine Writes lane
    .environment { $0.heroDetail }

let appBehavior = Behavior.combine(
    Library.behavior().lift(library),
    HeroDetails.behavior().lift(heroDetail)   // active only while heroDetail != nil
)

let store = Store(initial: .init(), behavior: appBehavior, environment: appEnv)

// Render the module — the opaque view() hides ViewState/ViewAction/Content behind `some View`:
Library.view(
    store: store.projection(action: AppAction.library, state: { $0.library }),   // plain closures
    environment: appEnv.library
)
```

That total projection fits a **present** sibling. When the child slice is **optional** (like `heroDetail: HeroDetails.State?`), a view decides whether to show it — so it reads through the app's **view store** (`@OwnedStore var root = store`), focuses the slice and transposes it, inverting `Store<HeroDetails.State?>` into `Store<HeroDetails.State>?`. The child view exists only while the state is `.some`, with no placeholder, and the parent depends only on that presence edge:

```swift
if let hero = root.focus(.action(\.heroDetail).state(\.heroDetail)).transpose() {
    HeroDetails.view(store: hero, environment: appEnv.heroDetail)
}
```

Only `State`/`Action`/`Environment`/`Input` and the opaque `view()` cross the module boundary; the entire view layer (`ViewState`, `ViewAction`, `Content`) stays `internal`.

## Testing a feature

A feature's `behavior()` is a pure value, so `TestStore` from `SwiftRex.Testing` drives it deterministically — no app, no mocks, just stubbed `Environment` closures. `dispatch` runs the behavior and asserts the resulting `State`; `runEffects()` drives captured effects; `receive` matches the produced action against a `Prism` (`@Feature` already applied `@Prisms` to `Action`).

```swift
@MainActor
@Test func fetch_populatesBooks() async {
    let books = [Book(id: "1", title: "Dune")]
    let store = TestStore(
        initial: Library.initialState(with: .init(shelfID: "sci-fi")),
        behavior: Library.behavior(),
        environment: Library.Environment(fetch: { _ in books })
    )

    store.dispatch(.onAppear) { $0.isLoading = true }
    await store.runEffects()
    store.receive(Library.Action.prism.loaded) { loaded, state in
        state.books = loaded
        state.isLoading = false
    }
}
```

## See Also

- <doc:BuildYourFirstFeature>
- <doc:AddingEffects>
- <doc:Modularisation>
- <doc:Lifting>
- ``Behavior``
- ``Store``
- ``StoreBuffer``
- ``StoreProjection``
