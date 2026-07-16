# Features with @Feature

Co-locate a whole feature — state, actions, behavior, and its SwiftUI screen — in one `enum`, and climb from the leanest possible feature to a full module one concern at a time.

## Overview

`SwiftRex.Architecture` is the opinionated layer on top of `SwiftRex.SwiftUI`. Where <doc:BuildYourFirstFeature> wires a `Store`, a `Behavior`, and a view by hand, `@Feature` folds that wiring into a single `enum` namespace: you describe the feature, and the macro synthesizes `initialState(with:)` and an erased `view(store:environment:) -> some View`, applies `@ApplyOptics(recursively: true)` to `State`, `Action`, and any other nested domain type — `@Lenses` for structs, `@Prisms` for enums, recursively down the whole nested tree — and builds the right kind of observable view store. (State you declare in an *extension* of the feature isn't visible to the macro: annotate that extension with `@ApplyOptics(recursively: true)` yourself.)

`@Feature(strategy:)` takes one knob:

- **`strategy:`** — a `ViewStrategy`, the observation mechanism the view store uses. `.observationSimple` builds a coarse ``ViewStore``; `.observationGranular` builds a field-level ``TrackedViewStore`` and auto-applies `@Tracked` to the `ViewState`; `.combineObservable` builds a Combine `ObservableObjectStore`. The first two require iOS 17; the last works back to iOS 13.

**Access follows the `enum`'s own modifier** — exactly like `@BoundTo` and `@Tracked`. A `public enum` is a module's public entry: the generated `view()`/`initialState(with:)` are `public`, so the composing app can render and seed it (declare its `State`/`Action`/`Environment`/`Input` `public` too, so they can be lifted). A plain `enum` is a screen composed *inside* a module — its generated members stay `internal`. There is no `type:` argument; the declaration says it.

**The `Feature` conformance is generated too.** A feature that builds a view (it has a `Content`, or a hand-written `view`) conforms to ``Feature`` — you never write `extension X: Feature {}` by hand. A view-less feature is a behavior only: it gets no `Feature` conformance, and (it already has `behavior()`) declares `: HasBehavior` itself in one line on the rare occasion it must be used through that protocol.

The paired SwiftUI view carries `@BoundTo(Feature.self, strategy:)`, which injects a `viewStore` stored property with the wrapper matching the strategy. The view body is the same across all three strategies — `viewStore.state.<field>` to read, `viewStore.dispatch(.<action>)` to send.

This article is the full L0→L4 progression; the [README](https://github.com/SwiftRex/SwiftRex#readme) shows the condensed form — one feature in one screen.

> `@Feature` requires a **Swift 6.3+** toolchain. The macro is not availability-gated, so a `.combineObservable` feature builds to the package floor (iOS 16, macOS 13, tvOS 16, watchOS 9); on Linux/Windows/Android the whole SwiftUI/Observation layer compiles out.

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
@Feature(strategy: .observationSimple)
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

@BoundTo(Counter.self, strategy: .observationSimple)
struct CounterView: View {
    // injected: let viewStore: ViewStore<Counter.State, Counter.Action>
    var body: some View {
        Button("count: \(viewStore.state.count)") { viewStore.dispatch(.tick) }
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
@Feature(strategy: .observationSimple)
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

Because ``ViewStore`` conforms to ``StoreType``, the store-backed SwiftUI helpers work straight off the `viewStore` — including two-way `binding`s whose write dispatches a `ViewAction`:

```swift
@BoundTo(HeroDetails.self, strategy: .observationSimple)
struct HeroDetailsView: View {
    // injected: let viewStore: ViewStore<HeroDetails.ViewState, HeroDetails.ViewAction>
    var body: some View {
        Form {
            Text(viewStore.state.displayName).font(.headline)
            // `set:` is `(Value) -> ViewAction`, so pass the case constructor directly:
            TextField("Powers", text: viewStore.binding(\.powersText, set: HeroDetails.ViewAction.editedPowers))
            Toggle("Retired", isOn: viewStore.binding(\.isRetired, set: { _ in .tappedRetirement }))
        }
    }
}
```

`binding` comes in two spellings. The **key-path** form above — `binding(\.powersText, set: ViewAction.editedPowers)` — reads a slice and dispatches a set action. The **``Relay/Scope``** form is the vocabulary-consistent sibling: an action lane that *embeds* and a state lane that *reads* the **same** value type couple into a `Binding` of that value.

```swift
// Equivalent to the key-path binding above — state reads the `String`, action embeds the `String`:
TextField("Powers", text: viewStore.binding(.action(HeroDetails.ViewAction.prism.editedPowers).state(\.powersText)))
```

## L3 — pick your observation

The strategy is the only thing that changes between the three variants — the view **body is identical**. `.observationGranular` builds a ``TrackedViewStore`` and applies `@Tracked` to the `ViewState` for you, giving field-level invalidation: SwiftUI registers per-field dependencies during `body`, so only views reading a changed field re-render. `.combineObservable` is the pre-Observation path — a Combine `ObservableObjectStore` bound as `@ObservedObject`, available back to iOS 13, coarse-grained.

```swift
// Field-level — @Tracked auto-applied to ViewState
@Feature(strategy: .observationGranular)
enum Gadget {
    struct State: Sendable, Equatable { var name = "phone"; var battery = 100 }
    enum Action: Sendable { case rename(String) }
    struct ViewState: Sendable, Equatable { var title: String; var charge: Int } // no @Tracked here — added for you
    enum ViewAction: Sendable { case tapped }
    static let mapState  = Reader<Void, @MainActor @Sendable (State) -> ViewState> { _ in { .init(title: $0.name, charge: $0.battery) } }
    static let mapAction = Reader<Void, @Sendable (ViewAction) -> Action>          { _ in { _ in .rename("x") } }
    static func behavior() -> Behavior<Action, State, Environment> {
        .reduce { a, s in switch a { case .rename(let n): s.name = n } }
    }
    typealias Content = GadgetView
}

@BoundTo(Gadget.self, strategy: .observationGranular)
struct GadgetView: View {
    // injected: let viewStore: TrackedViewStore<Gadget.ViewState, Gadget.ViewAction>
    var body: some View { Text(viewStore.state.title) }   // invalidates only when `title` changes
}

// Combine — iOS 13+; the generated view() is ungated
@BoundTo(Widget.self, strategy: .combineObservable)
struct WidgetView: View {
    // injected: @ObservedObject var viewStore: ObservableObjectStore<Widget.ViewAction, Widget.ViewState>
    var body: some View { Text(viewStore.state.label) }
}
```

Under `.observationGranular` with no distinct `ViewState`, `@Tracked` lands on `State` itself — you still get a ``TrackedViewStore``, just over the domain state. Prefer `.observationSimple` unless you have a genuinely hot, wide screen where field-level tracking measurably wins; SwiftUI's own structural diffing already keeps coarse redraws cheap.

## L4 — a full module

A `public enum` module entry point is the only thing a composing app sees of a module. Its `State`/`Action`/`Environment`/`Input` are `public` (they must be liftable), and — because access follows the `enum` — so are the generated `view(store:environment:)` and `initialState(with:)`. It adds a seed (`Input`), an effect through the behavior, and state-driven navigation.

```swift
@Feature(strategy: .observationSimple)
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

Navigation is state-driven: the `item` binding presents while `selected` is `.some` and only ever dispatches the *dismiss* action when SwiftUI clears it — presentation is always a function of state, never driven by the binding. The sibling `presence` binding does the same for `.sheet(isPresented:)`.

```swift
@BoundTo(Library.self, strategy: .observationSimple)
struct LibraryView: View {
    // injected: let viewStore: ViewStore<Library.State, Library.Action>
    var body: some View {
        List(viewStore.state.books) { book in
            Button(book.title) { viewStore.dispatch(.tapped(book)) }
        }
        .onAppear { viewStore.dispatch(.onAppear) }
        .sheet(item: viewStore.item(\.selected, dismiss: .dismissedDetail)) { book in
            Text(book.title)
        }
    }
}
```

## Composing modules into the app

The app lifts each feature's `behavior()` into the parent store and renders it through the erased `view()`. A whole child module lifts through a ``Relay/Scope`` (`.action(…).state(…).environment(…)`); an *optional* child screen uses an optional state key path (an **affine** state lane — it runs only while the sub-state is `.some`); a collection of children through `liftCollection` — see <doc:Lifting> and <doc:Modularisation>.

```swift
let appBehavior = Behavior.combine(
    Library.behavior().lift(
        Relay.Empty
            .action(AppAction.prism.library)         // a Prism<AppAction, Library.Action>
            .state(\AppState.library)                // total WritableKeyPath → ReadsWrites lane
            .environment { $0.library }
    ),
    HeroDetails.behavior().lift(                      // active only while heroDetail != nil
        Relay.Empty
            .action(AppAction.prism.heroDetail)
            .state(\AppState.heroDetail)             // optional key path → affine Writes lane
            .environment { $0.heroDetail }
    )
)

let store = Store(initial: .init(), behavior: appBehavior, environment: appEnv)

// Render the module — the opaque view() hides ViewState/ViewAction/Content behind `some View`:
Library.view(
    store: store.projection(action: AppAction.library, state: { $0.library }),   // plain closures
    environment: appEnv.library
)
```

That total projection fits a **present** sibling. When the child slice is **optional** (like `heroDetail: HeroDetails.State?`), project it and ``StoreType/transpose()`` — inverting `Store<HeroDetails.State?>` into `Store<HeroDetails.State>?` — so the child view exists only while the state is `.some`, with no placeholder:

```swift
if let heroStore = store.projection(action: AppAction.heroDetail, state: { $0.heroDetail }).transpose() {
    HeroDetails.view(store: heroStore, environment: appEnv.heroDetail)
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
- ``ViewStore``
- ``TrackedViewStore``
