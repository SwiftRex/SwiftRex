<p align="center">
	<a href="https://github.com/SwiftRex/SwiftRex/"><img src="https://swiftrex.github.io/SwiftRex/markdown/img/SwiftRexBanner.png" alt="SwiftRex" /></a><br /><br />
	Unidirectional Dataflow for Swift<br /><br />
</p>

![Build Status](https://github.com/SwiftRex/SwiftRex/actions/workflows/ci.yml/badge.svg?branch=main)
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-orange.svg)](https://swiftpackageindex.com/SwiftRex/SwiftRex)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FSwiftRex%2FSwiftRex%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/SwiftRex/SwiftRex)
[![Platform support](https://img.shields.io/badge/platform-iOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20macOS%20%7C%20visionOS%20%7C%20Linux-252532.svg)](https://github.com/SwiftRex/SwiftRex)
[![License Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/SwiftRex/SwiftRex/blob/main/LICENSE)

SwiftRex is a [Redux](https://redux.js.org/basics/data-flow)-style unidirectional-dataflow framework for Swift. One `Store` owns your whole app state; views dispatch **actions**, pure **behaviors** describe what changes and what runs, and the Store — the only thing that executes anything — mutates state and performs effects. It works with the reactive runtime you already use: Swift Concurrency, Combine, [RxSwift](https://github.com/ReactiveX/RxSwift), [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift), or [ReactiveConcurrency](https://github.com/luizmb/ReactiveConcurrency).

- **Single source of truth** — one state tree, one store; views observe projections of it.
- **Compiler-enforced layers** — everything but the Store is an inert, composable value; there is nowhere to hide a side-effect.
- **No race conditions** — every event is an action, processed FIFO on `@MainActor`, one notification per change.
- **Testable without mocks** — environments are plain closures, logic is pure functions.
- **Modular** — features are written against their own small types and *lifted* into the app; reuse them across apps and platforms, including Linux.

[Full documentation lives in the DocC catalog](https://swiftrex.github.io/SwiftRex/documentation/swiftrex) — this README is the pragmatic tour; the articles go deeper (and, where you want it, [into the algebra](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/algebra)).

# A feature in one screen

```swift
import SwiftRex
import SwiftRexArchitecture   // @Feature, @BoundTo
import SwiftUI

@Feature(type: .internalOnly, strategy: .observationSimple)
enum Movies {
    struct State: Sendable, Equatable {
        var movies: [Movie] = []
        var isLoading = false
    }

    enum Action: Sendable {
        case onAppear
        case loaded(Result<[Movie], APIError>)
    }

    struct Environment: Sendable {
        var fetchMovies: @Sendable () async -> Result<[Movie], APIError>
    }

    static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, _ in
            switch action {
            case .onAppear:
                .reduce { $0.isLoading = true }
                .produce { ctx in Effect.task { .loaded(await ctx.environment.fetchMovies()) } }
            case .loaded(.success(let movies)):
                .reduce { $0.movies = movies; $0.isLoading = false }
            case .loaded(.failure):
                .reduce { $0.isLoading = false }
            }
        }
    }

    typealias Content = MoviesView
}

@BoundTo(Movies.self, strategy: .observationSimple)
struct MoviesView: View {
    // injected: let viewStore: ViewStore<Movies.State, Movies.Action>
    var body: some View {
        List(viewStore.state.movies) { movie in Text(movie.title) }
            .onAppear { viewStore.dispatch(.onAppear) }
    }
}
```

Everything above is a pure value. To run it, create the one object in the whole design — the `Store` — at your app's entry point:

```swift
@State var store = Store(
    initial: Movies.initialState(with: ()),
    behavior: Movies.behavior(),
    environment: Movies.Environment(fetchMovies: { await API.live.movies() })
)
```

The [Build Your First Feature](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/buildyourfirstfeature) article walks through this step by step.

# Installation

Swift Package Manager, Swift 6.3+ toolchain (the `@Feature` macro requires it). Platforms: macOS 13+, iOS 16+, tvOS 16+, watchOS 9+, visionOS 1+, Linux.

```swift
dependencies: [
    .package(
        url: "https://github.com/SwiftRex/SwiftRex.git",
        from: "0.8.8",
        traits: ["ReactiveConcurrency"]   // only if you use a trait-gated bridge; omit otherwise
    )
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "SwiftRex", package: "SwiftRex"),
        .product(name: "SwiftRex.SwiftConcurrency", package: "SwiftRex"),
        .product(name: "SwiftRex.SwiftUI", package: "SwiftRex"),
        .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
    ]),
    .testTarget(name: "MyAppTests", dependencies: [
        "MyApp",
        .product(name: "SwiftRex.Testing", package: "SwiftRex"),
    ])
]
```

Pick the products that match your project; the core is self-contained:

| Product | Trait | What it adds |
|---|---|---|
| `SwiftRex` | — | The core: store, reducers, middlewares, behaviors, effects, channels |
| `SwiftRex.SwiftConcurrency` | — | `Effect.task`/`.throwingTask`/`.asyncSequence`, `asChannel` on `AsyncSequence`, `store.stream` |
| `SwiftRex.Combine` | — | `asEffect()`/`asChannel()` on `Publisher`, `store.publisher`, `ctx.readLiveState()` |
| `SwiftRex.RxSwift` | `RxSwift` | The same bridge surface for `Observable` |
| `SwiftRex.ReactiveSwift` | `ReactiveSwift` | The same bridge surface for `SignalProducer`/`Signal` |
| `SwiftRex.ReactiveConcurrency` | `ReactiveConcurrency` | The same bridge surface for ReactiveConcurrency's cold, async/await-native `Publisher` |
| `SwiftRex.SwiftUI` | — | `ViewStore`/`TrackedViewStore` (`@Observable`, iOS 17+), `asObservableObject()` (iOS 13+), store-backed `Binding`s |
| `SwiftRex.Architecture` | — | The `@Feature` / `@BoundTo` macros and `Scope` (Swift 6.3+) |
| `SwiftRex.Operators` | — | Symbolic operators (`<>`, `\|>`, `>>>`, …) |
| `SwiftRex.Testing` | — | `TestStore` — test target only |

The three third-party bridges are each gated behind a [package trait](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md) of the same name, **off by default** — picking one bridge never downloads the other two. In Xcode, tick the trait in the **Traits** column of **Project ▸ Package Dependencies**:

![Enabling the ReactiveConcurrency trait for SwiftRex in Xcode's Package Dependencies (Traits column showing "default, ReactiveConcurrency")](Sources/SwiftRex/SwiftRex.docc/Resources/xcode-package-traits.png)

Xcode project caveats (trait propagation in `project.pbxproj`, XcodeGen) and pre-built XCFrameworks are covered in the [Installation article](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/installation).

# The core loop

```
        ┌────────── dispatch(action) ──────────┐
        │                                      ▼
   ┌─────────┐                            ┌─────────┐   reduce    ┌───────────┐
   │  View   │                            │  Store  │────────────▶│   State   │
   └─────────┘                            │ (runs)  │             └───────────┘
        ▲                                 └─────────┘                   │
        │                                      │ produce / supervise    │
        │                                 ┌─────────┐                   │
        └───────── observes state ────────│ Effects │── new actions ────┘
                                          └─────────┘      loop back
```

- An **Action** is a plain value describing something that happened — a tap, a response, a tick. Model them as enums, grouped per feature.
- **State** is a plain value holding everything your app knows right now — one tree, structs and enums.
- A **Behavior** is a pure value describing how the feature responds: what to *reduce* (mutate), what to *produce* (run once), what to *supervise* (keep alive).
- The **Store** is the only executor. It receives every action, applies the mutation (one notification per change), performs the effects, and loops effect results back in as new actions.

Modelling tips for actions and state live in [State and Actions](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/stateandactions).

# Behavior — the fluent interface

`Behavior<Action, State, Environment>` is the recommended unit of logic. It fuses the three concerns a feature can have, one fluent builder per axis:

| Builder | Concern | The Store… |
|---|---|---|
| `.reduce { action, state in … }` | state change — pure `(Action, inout State) -> Void` | **mutates** |
| `.produce { action, ctx in … }` | action-driven effect — an action triggers an `Effect` | **performs** |
| `.supervise { state in … }` | state-driven effect — the state implies live `Channel`s | **keeps** |

```swift
let feature = Behavior<Action, State, Environment>
    .reduce { action, state in … }      // what changes
    .produce { action, ctx in … }       // what to run because something happened
    .supervise { state in … }           // what to keep alive while the state holds
```

`.handle { action, ctx in … }` groups the first two per action — you saw it in the hero example: switch once, return `.reduce`, `.produce`, or a chain of both.

Behaviors compose with `<>` (or `Behavior.combine`): mutations fold in order, effects merge in parallel, supervisions union. And `.on(...)` chains declarative action-routing onto any behavior:

```swift
let routed = Behavior<AppAction, AppState, World>.identity
    .on(\.didTapLogout, dispatch: AppAction.auth(.logout))
    .on(\.didLoad, dispatch: AppAction.renderItems, when: { !$0.isLoading })
```

The full `.on` catalog (Prism, KeyPath, predicate, and pure-routing families) is on the [Behavior reference page](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/behavior).

# Effects: Command or Subscription?

The one design decision you'll make over and over: is this effect **action-driven** or **state-driven**?

| | Command — `.produce` | Subscription — `.supervise` |
|---|---|---|
| Shape | one-shot: fire → complete | long-lived: emits over time |
| Trigger | *this action happened, so do that* | *the state implies it should exist* |
| Examples | HTTP fetch, save/delete a document, request a permission | socket, GPS stream, timer, DB observer, push listener |
| Teardown | completes by itself | leaving the state **is** the teardown |
| Elm analogy | `Cmd` | `Sub` |

A CRUD or document app is usually **all Commands** — discrete IO, nothing long-lived. The hero example's fetch is one. A monitor-style feature — location, live prices, chat — is the genuine **Subscription** case:

```swift
let room = Behavior<RoomAction, RoomState, RoomEnv>
    .reduce { action, state in
        switch action {
        case .join(let id):    state.joinedRoom = id
        case .leave:           state.joinedRoom = nil
        case .received(let m): state.messages.append(m)
        }
    }
    .supervise { state in
        Supervision { env in
            guard let id = state.joinedRoom else { return [] }   // no room → no socket
            return [Channel(id: id) { dispatch in
                let socket = env.connect(id)
                socket.onMessage { dispatch(.received($0)) }          // events out → actions
                return ChannelHandler(receive: { socket.write($0) },  // values in → the resource
                                      cancel:  { socket.close() })    // teardown, written once
            }]
        }
    }
```

After every mutation the Store recomputes the desired channel set and **reconciles**: newly-present channels open, now-absent channels cancel, unchanged ones are left untouched. When `joinedRoom` becomes `nil` the socket closes — you never wire `socket.close()` to a `.leave` action, and you never write manual `replacing(id:)` cancellation bookkeeping. Because the desired set is a pure function of state, it can't leak and can't double-open.

Prefer a **Command** when the work is discrete and owns its own completion. Prefer a **Supervisor** when the resource must live exactly as long as some state holds — if you find yourself dispatching "start X" and "stop X" action pairs and cancelling by id, that's a Subscription wanting to happen. The two also meet in the middle: a `.produce` can send *into* a live supervised channel via `Effect.broadcast(_:channel:)` (the send half of a two-way socket).

Deep dives: [State-Driven Effects](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/statedriveneffects) · [Channels](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/channels) · worked examples for a [timer](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/exampletimer), [polling](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/examplepolling), a [chat room](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/examplechatroom), a [WebSocket](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/examplewebsocket), and [per-value delay](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/exampledelay).

# Pick your reactive framework

The core `Effect` is deliberately runtime-agnostic; each companion product bridges your streams into effects and channels with the same two verbs — `asEffect` for Commands, `asChannel` for Subscriptions.

**Swift Concurrency** (`SwiftRex.SwiftConcurrency`, no third-party dependency):

```swift
// one-shot async work
.produce { ctx in
    Effect.task { .loaded(await ctx.environment.fetch()) }
}

// throwing work — the Result arrives in the action
Effect.throwingTask(Action.saved) { try await ctx.environment.save(draft) }

// any AsyncSequence becomes a supervised channel
.supervise { state in
    Supervision { env in
        guard state.isTracking else { return [] }
        return [env.locationUpdates().asChannel(id: "location", Action.located)]
    }
}

// observe the store outside SwiftUI
for await state in store.stream() { render(state) }
```

**ReactiveConcurrency** (`SwiftRex.ReactiveConcurrency`, trait-gated) — a cold, `Sendable`, async/await-native `Publisher`, ideal when your environment is `@Sendable (Args) -> Publisher<Value, Failure>`:

```swift
// Publisher → Effect; failures arrive as a Result in the action
.produce { ctx in
    ctx.environment.search(query)        // Publisher<[Movie], APIError>
        .asEffect(Action.results)        // Effect<Action>
}

// Publisher → supervised channel
.supervise { state in
    Supervision { env in
        state.isWatchingPrices ? [env.priceFeed().asChannel(id: "prices", Action.tick)] : []
    }
}

// observe the store as a cold Publisher<State, Never>
store.publisher
```

Combine (`store.publisher`, `asEffect`/`asChannel` on any `Publisher`), RxSwift (`Observable`), and ReactiveSwift (`SignalProducer`/`Signal`) expose the exact same surface — swap the runtime, keep the architecture. Mixing is fine too: Combine in the app target, a portable bridge in library code.

# Middleware and Reducer

`Behavior` is a fusion of two smaller values that still exist and compose on their own — reach for them when a unit genuinely has only one concern, or when reusing pre-Behavior code:

- **`Reducer<Action, State>`** — only the mutation axis, a named pure function:

```swift
let counterReducer = Reducer<CounterAction, Int>.reduce { action, count in
    switch action {
    case .increment: count += 1
    case .decrement: count -= 1
    }
}
```

- **`Middleware<Action, State, Environment>`** — only the effect axes (`produce` + `supervise`); it can read state before and after mutation but never write it:

```swift
let favorites = Middleware<FavoritesAction, FavoritesState, API>.handle { action, context in
    guard case .toggleFavorite(let id) = action else { return .doNothing }
    let wasFavorite = context.stateBefore?.favorites.contains(id) ?? false
    return .produce { ctx in
        Effect.task { .changedFavorite(await ctx.environment.setFavorite(id, to: !wasFavorite)) }
    }
}
```

Pair them back up with `Behavior(reducer:middleware:)`, or lift either half alone via `reducer.asBehavior()` / `middleware.asBehavior` and compose with `<>`. Reference: [Reducer](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/reducer) · [Middleware](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/middleware).

# The `@Feature` macro

`SwiftRex.Architecture` packages the recommended app structure. `@Feature(type:strategy:)` turns a namespace enum into a full feature: it applies `@Prisms` to `Action`, `@Lenses` to `State`, and generates `initialState(with:)` and the SwiftUI `view(store:environment:)` factory. `@BoundTo` injects the matching `viewStore` into the view — the body never changes when you swap observation strategies.

You saw the minimal shape in the hero example. Features scale up by *adding* declarations, never rewriting: an `Environment` for dependencies, a distinct `ViewState`/`ViewAction` pair with `mapState`/`mapAction` as `Reader<Environment, …>` when the view's shape diverges from the domain's, an `Input` seed for parameterised features, `.observationGranular` for field-level view invalidation, and `type: .moduleEntryPoint` when the feature becomes its own SPM module:

```swift
@Feature(type: .moduleEntryPoint, strategy: .observationGranular)
public enum HeroDetails {
    public struct State: Sendable, Equatable { … }
    public enum Action: Sendable { … }
    public struct Environment: Sendable { … }

    public struct ViewState: Sendable, Equatable { … }   // what the pixels need
    public enum ViewAction: Sendable { case onAppear }   // what the pixels can say

    public static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { env in
        { state in ViewState(state, formatter: env.formatter) }
    }
    public static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action> { _ in
        { viewAction in .load }
    }

    public static func behavior() -> Behavior<Action, State, Environment> { … }
    public typealias Content = HeroDetailsView
}

extension HeroDetails: Feature {}   // one line; the members already exist
```

The whole L0→L4 progression — leanest feature to full module — is in the [Features article](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/features).

# Modularity — lifting, Scope, and bridges

Features never know about the app. They're written against local types and **lifted** to the global ones at the composition root. With `@Prisms`/`@Lenses` on the root types, lifting is just key paths:

```swift
@Prisms enum AppAction: Sendable {
    case movies(Movies.Action)
    case player(Player.Action)
}

@Lenses struct AppState: Sendable, Equatable {
    var movies = Movies.State()
    var player = Player.State()
}

let moviesBehavior: Behavior<AppAction, AppState, World> =
    Movies.behavior().lift(
        action:      \.movies,          // PrismKeyPath — narrows incoming, embeds outgoing
        state:       \AppState.movies,  // WritableKeyPath — focus the slice
        environment: { world in Movies.Environment(fetchMovies: world.api.movies) }
    )
```

Every lift carries all three axes — including `supervise`, so a lifted feature's channels cancel automatically when its sub-state disappears. `liftOptional` handles optional sub-state, `liftCollection`/`liftEach` run one behavior per element of a collection.

**`Scope`** bundles a feature's whole wiring — action prism, state slice, environment narrowing — into one declared, compile-checked value used by both the store fold *and* the view router:

```swift
typealias LiftedScope<F: Feature> = Scope<AppAction, AppState, World, F>

extension LiftedScope<Movies> {
    static var movies: Self {
        Scope(Movies.self, action: \.movies, state: \.movies,
              environment: { world in .init(fetchMovies: world.api.movies) })
    }
}

let store = Store(
    initial: AppState(),
    behavior: LiftedScope<Movies>.movies.behavior
           <> LiftedScope<Player>.player.behavior,
    environment: world
)

// …and in the router, the same Scope builds the screen:
LiftedScope<Movies>.movies.view(from: store, world: world)
```

**Bridge behaviors** connect modules without coupling them. Prisms compose with `>>>`, so a root-level `.on` can route one feature's output into another feature's input — neither module imports the other:

```swift
let bridge = Behavior<AppAction, AppState, World>.identity
    .on(AppAction.prism.player >>> Player.Action.prism.finished,
        dispatch: { movieID in .movies(.markWatched(movieID)) })

// compose it into the store fold like any other behavior:
behavior: LiftedScope<Movies>.movies.behavior
       <> LiftedScope<Player>.player.behavior
       <> bridge
```

Deep dives: [Lifting](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/lifting) · [Modularisation](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/modularisation).

# Navigation

Navigation is a function of state: routes live in the state tree, behaviors mutate them, and SwiftUI containers bind to them — every binding is a (state-path, action) pair whose setter dispatches.

| State shape | Binding | Container |
|---|---|---|
| `Route?` / `Bool` | `store.item(…)` / `store.presence(…)` | `.sheet`, `.fullScreenCover`, `.popover` |
| `[Route]` | `store.path(…)` | `NavigationStack(path:)` |
| selection enum / id | `store.selection(…)` | `TabView`, `NavigationSplitView` |
| collection of scene ids | `store.hasScene(…)` | `WindowGroup(for:)` |

```swift
NavigationStack(path: store.path(\.nav.path, set: { .nav(.setPath($0)) })) {
    HomeView()
        .navigationDestination(for: AppRoute.self) { route in
            route.view(in: store, world: world)   // a switch over Scopes — no AnyView
        }
}
```

Dismissal is popping state, deep links are just setting state, and a route's supervised effects cancel when its state leaves the tree. The [Navigation article](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/navigation) covers all four shapes, `Scope`-based routers, and deep linking.

# Testing

`SwiftRex.Testing` ships `TestStore` — deterministic and exhaustive. Add it to your test target only. Because environments are plain closures, tests stub functions — no mocks, no protocols:

```swift
@MainActor
@Test func fetch_populatesBooks() async {
    let books = [Book(id: "1", title: "Dune")]

    let store = TestStore(
        initial: Library.initialState(with: .init(shelfID: "sci-fi")),
        behavior: Library.behavior(),
        environment: Library.Environment(fetch: { _ in books })
    )

    store.dispatch(.onAppear) { _ in }        // assert state; an effect is queued
    await store.runEffects()
    store.receive(Library.Action.prism.loaded) { loaded, state in
        state.books = loaded                  // describe the expected post-action state
    }
}
```

`dispatch` asserts the state after each action; `runEffects()` drives pending effects; `receive` matches produced actions by `Prism` (so `Action` needn't be `Equatable` — handy when a case carries a `Result`). By default the store fails the test on unasserted actions, leftover effects, or channels still open at deallocation; pass `exhaustive: false` to relax.

# Documentation

Start here:
[Installation](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/installation) ·
[Build Your First Feature](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/buildyourfirstfeature) ·
[Adding Effects](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/addingeffects) ·
[Features](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/features) ·
[Navigation](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/navigation)

Concepts:
[State and Actions](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/stateandactions) ·
[Lifting](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/lifting) ·
[Modularisation](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/modularisation) ·
[The Algebra](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/algebra)

State-driven effects:
[State-Driven Effects](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/statedriveneffects) ·
[Channels](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/channels) ·
examples: [Timer](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/exampletimer), [Polling](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/examplepolling), [Chat Room](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/examplechatroom), [WebSocket](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/examplewebsocket), [Delay](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/exampledelay)

Reference:
[Behavior](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/behavior) ·
[Reducer](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/reducer) ·
[Middleware](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/middleware) ·
[Effect](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/effect) ·
[Store](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/store)

Tooling: [LoggerMiddleware](https://github.com/SwiftRex/LoggerMiddleware) · [InstrumentationMiddleware](https://github.com/SwiftRex/InstrumentationMiddleware)

# License

Apache 2.0 — see [LICENSE](LICENSE). Contributions welcome: [CONTRIBUTING.md](CONTRIBUTING.md) · [Code of Conduct](CODE_OF_CONDUCT.md).
