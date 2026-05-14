# SwiftRex — Full Rewrite Architecture

> Branch: `full-rewrite`

## Goals

- Effect system is **framework-agnostic** — no per-framework `Effect` types in the core
- Grounded in proper FP vocabulary: monoid, functor, monad, Reader, contravariant functor
- Depend on [`github.com/luizmb/FP`](https://github.com/luizmb/FP) for core FP primitives
- All operators optional — live in a separate `SwiftRexOperators` product
- Runs on every Swift platform: macOS, iOS, tvOS, watchOS, **Linux, Windows, WASM**
- Reducer and Middleware are pure structs; the Store (`actor`) is the only stateful entity

---

## Platform Targets

| Platform | Minimum |
|---|---|
| macOS | 12.0 |
| iOS / iPadOS | 15.0 |
| tvOS | 15.0 |
| watchOS | 8.0 |
| Linux | any modern Swift toolchain |
| Windows | any modern Swift toolchain |
| Embedded | excluded |

Requires **Swift 5.9+** (for `package` access level used to share Effect internals across targets within the package).

---

## Dependency: `github.com/luizmb/FP`

| Module | Used for |
|---|---|
| `CoreFP` | Functor / Applicative / Monad hierarchy, Monoid / Semigroup, Array / Optional / Result extensions |
| `DataStructure` | `Reader<Env, A>`, `Writer<Log, A>`, `Stateful<S, A>`, `ZIO<R, W, A>`, `Either`, `Validation`, `NonEmpty`, optics (`Lens`, `Prism`, `AffineTraversal`, `Iso`) |
| `CoreFPOperators` | Symbolic operators — **SwiftRexOperators target only** |
| `DataStructureOperators` | Symbolic operators — **SwiftRexOperators target only** |

The core `SwiftRex` target imports `CoreFP` and `DataStructure` but **never** the operator modules. All composition in core code uses named functions (`append`, `contramap`, `lift`, …). Symbolic operators (`<>`, `|>`, …) are opt-in via `SwiftRexOperators`.

---

## Package Structure

```
SwiftRex (Package.swift)
│
├── Products
│   ├── SwiftRex            — core; imports FP[CoreFP, DataStructure]
│   ├── SwiftRexOperators   — operator sugar; imports FP[CoreFPOperators, DataStructureOperators]
│   ├── CombineRex          — Combine bridges
│   ├── RxSwiftRex          — RxSwift bridges
│   └── ReactiveSwiftRex    — ReactiveSwift bridges
│
└── Targets
    ├── SwiftRex/
    │   ├── Foundation/
    │   │   ├── ActionSource.swift
    │   │   ├── DispatchedAction.swift
    │   │   ├── ElementAction.swift
    │   │   └── SubscriptionToken.swift
    │   ├── Reducer/
    │   │   ├── Reducer.swift
    │   │   ├── Reducer+Lift.swift
    │   │   └── Reducer+LiftCollection.swift
    │   ├── Core/
    │   │   ├── Effect.swift
    │   │   ├── Middleware.swift
    │   │   ├── ActionHandler.swift
    │   │   └── Store.swift
    │   └── Lifting/
    │       ├── Reducer+Lift.swift
    │       └── Middleware+Lift.swift
    │
    ├── SwiftRexOperators/
    │   ├── Reducer+Operators.swift
    │   ├── Middleware+Operators.swift
    │   └── Lift+Operators.swift
    │
    ├── CombineRex/
    │   ├── Effect+Publisher.swift
    │   ├── Store+Publisher.swift
    │   └── SwiftUI/
    │       ├── ObservableViewModel.swift      — ObservableObject (iOS 13+)
    │       └── ObservableStore.swift          — @Observable (iOS 17+)
    │
    ├── RxSwiftRex/
    │   ├── Effect+Observable.swift
    │   └── Store+Observable.swift
    │
    └── ReactiveSwiftRex/
        ├── Effect+SignalProducer.swift
        └── Store+SignalProducer.swift
```

Sources for `Reducer` are merged from `github.com/SwiftRex/Reducer` directly into this monorepo (no separate package dependency).

---

## Core Types

### `Cancellation`

Our own cancellation token. Named `Cancellation` (not `Cancellable`) to avoid collision with Combine's `Cancellable` protocol.

```swift
public struct Cancellation {
    private let _cancel: () -> Void
    public init(_ cancel: @escaping () -> Void) { _cancel = cancel }
    public func cancel() { _cancel() }
    public static let empty = Cancellation { }
}
```

Bridge packages wrap their framework's token:
```swift
Cancellation { combineCancellable.cancel() }  // CombineRex
Cancellation { disposable.dispose() }          // RxSwiftRex
Cancellation { task.cancel() }                // async/await
```

---

### `ActionSource` and `DispatchedAction<Action>`

Every action in the system carries its call-site origin for debugging and tracing.

```swift
public struct ActionSource {
    public let file: String
    public let function: String
    public let line: UInt
    public let info: String?
}

public struct DispatchedAction<Action> {
    public let action: Action
    public let dispatcher: ActionSource
}
```

`ActionSource` is captured automatically at every **public API boundary** via default `#file / #function / #line` parameters. Users working inside middlewares see `DispatchedAction<InputAction>` on the incoming side; on the outgoing side they return raw `Action` values and the framework wraps them using the source captured at the `Effect` factory call site.

---

---

### `Reducer<Action, State>`

Pure state transformation. The only type that is allowed to mutate `State`.

```swift
public struct Reducer<Action, State> {
    public let reduce: (Action, inout State) -> Void
}
```

**FP structure — sequential Monoid:**
- `identity` — no-op reducer
- `append(lhs, rhs)` — run `lhs` then `rhs` on the same `inout State`; `rhs` sees `lhs`'s mutations
- Order matters (not commutative); associativity holds

```swift
extension Reducer: Monoid {
    public static var identity: Self { .init { _, _ in } }
    public static func append(_ lhs: Self, _ rhs: Self) -> Self {
        .init { action, state in
            lhs.reduce(action, &state)
            rhs.reduce(action, &state)
        }
    }
}
```

**Named constructors:**
```swift
extension Reducer {
    // Primary: inout
    public static func reduce(_ f: @escaping (Action, inout State) -> Void) -> Self

    // Bridge: pure functional style → converted to inout internally
    public static func pure(_ f: @escaping (Action, State) -> State) -> Self
}
```

**FP naming (Contravariant in Action, Profunctor in State):**
```swift
extension Reducer {
    // Contravariant functor in Action
    public func contramapAction<GlobalAction>(
        _ f: @escaping (GlobalAction) -> Action?
    ) -> Reducer<GlobalAction, State>

    // Profunctor in State (requires both get and set — a Lens)
    public func dimapState<GlobalState>(
        get: @escaping (GlobalState) -> State,
        set: @escaping (inout GlobalState, State) -> Void
    ) -> Reducer<Action, GlobalState>
}
```

**`lift` — unified multi-axis convenience:**
```swift
extension Reducer {
    // Both axes — KeyPath
    public func lift<GA, GS>(
        action: KeyPath<GA, Action?>,
        state: WritableKeyPath<GS, State>
    ) -> Reducer<GA, GS>

    // Both axes — closures
    public func lift<GA, GS>(
        action: @escaping (GA) -> Action?,
        stateGet: @escaping (GS) -> State,
        stateSet: @escaping (inout GS, State) -> Void
    ) -> Reducer<GA, GS>

    // State only
    public func lift<GS>(state: WritableKeyPath<GS, State>) -> Reducer<Action, GS>

    // Action only
    public func lift<GA>(action: KeyPath<GA, Action?>) -> Reducer<GA, State>

    // Collection lifting (Identifiable, custom ID, index) — unchanged from current repo
    public func liftToCollection<GA, GS, C: MutableCollection>(…) -> Reducer<GA, GS>
}
```

Optics overloads (`Prism<GA, Action>`, `Lens<GS, State>`) provided as secondary API alongside KeyPath variants.

---

### `Effect<Action>`

The unit of side-effectful computation returned by Middleware. Completely opaque — users never see `AsyncStream`, `Task`, `Publisher`, or any reactive type at the `Effect` level.

**Design principle:** creating an `Effect` starts no work. The Store is the sole executor; it calls the internal subscribe closure only when it is ready to run the effect. This preserves Middleware purity.

**Internal representation:**

```swift
public struct Effect<Action> {
    // `package` access: visible to all targets in this Package.swift, invisible to importers.
    // nil = empty (Monoid identity — nothing to run).
    package let _subscribe: ((@escaping (DispatchedAction<Action>) -> Void) -> Cancellation)?

    public let scheduling: EffectScheduling

    // For community bridge packages outside this repo:
    @_spi(EffectBridging)
    public init(
        subscribe: @escaping (@escaping (DispatchedAction<Action>) -> Void) -> Cancellation,
        scheduling: EffectScheduling = .immediately
    )
}
```

The subscribe closure is push-based: the Store gives it a callback `(DispatchedAction<Action>) -> Void`; the closure calls the callback for every action it produces and returns a `Cancellation` the Store can use to stop it.

**Scheduling — declarative, interpreted by the Store:**

```swift
public enum EffectScheduling: Sendable {
    case immediately
    case cancellable(id: AnyHashable)
    case debounce(id: AnyHashable, delay: Duration)
    case throttle(id: AnyHashable, interval: Duration)
    case cancelInFlight(id: AnyHashable)   // sentinel: cancel, produce nothing
}
```

**User-facing factories (no async primitives exposed):**

```swift
extension Effect {
    public static var empty: Self

    public static func just(
        _ action: Action,
        file: String = #file, function: String = #function
    ) -> Self

    public static func sequence(
        _ actions: [Action],
        file: String = #file, function: String = #function
    ) -> Self

    // Callback-based — GCD, URLSession, etc.
    public static func future(
        _ work: @escaping (@escaping (Action) -> Void) -> Void,
        file: String = #file, function: String = #function
    ) -> Self

    // Async/await single value
    public static func task(
        _ work: @escaping () async -> Action?,
        file: String = #file, function: String = #function
    ) -> Self

    // Side-effect only, no action dispatched back
    public static func fireAndForget(_ work: @escaping () async -> Void) -> Self

    // Cancellation sentinel
    public static func cancelInFlight<H: Hashable>(id: H) -> Self

    // Scheduling modifier
    public func scheduling(_ policy: EffectScheduling) -> Self
}
```

**ActionSource capture:** every factory captures `#file / #function` at the call site. Users return raw `Action` values inside closures; the framework wraps them in `DispatchedAction` using the captured source. Users never construct `DispatchedAction` directly.

**Bridge factories (in their respective targets):**
```swift
// CombineRex
extension Effect {
    public static func publisher<P: Publisher>(
        _ p: P, file: String = #file, function: String = #function
    ) -> Self where P.Output == Action, P.Failure == Never
}

// RxSwiftRex
extension Effect {
    public static func observable<O: ObservableType>(
        _ o: O, file: String = #file, function: String = #function
    ) -> Self where O.Element == Action
}

// ReactiveSwiftRex
extension Effect {
    public static func signalProducer<SP: SignalProducerConvertible>(
        _ sp: SP, file: String = #file, function: String = #function
    ) -> Self where SP.Value == Action, SP.Error == Never
}
```

**FP structure:**
```swift
// Functor
extension Effect {
    public func map<B>(_ f: @escaping (Action) -> B) -> Effect<B>
}

// Parallel Monoid — merges both subscribe closures (Store runs both concurrently)
extension Effect: Monoid {
    public static var identity: Self { .empty }
    public static func append(_ lhs: Self, _ rhs: Self) -> Self { … }
}
```

---

### `Middleware<InputAction, OutputAction, State, Environment>`

Pure struct. No instance state. All mutable state (running effects, debounce timers, throttle timestamps) lives in the Store.

```swift
public struct Middleware<InputAction, OutputAction, State, Environment> {
    // Receives the incoming dispatched action and a pre-reducer state getter.
    // Returns a Reader so environment injection is deferred to the Store.
    public let handle: (DispatchedAction<InputAction>, @escaping () -> State)
        -> Reader<Environment, Effect<OutputAction>>
}
```

**Named constructors:**
```swift
extension Middleware {
    public static func handle(
        _ f: @escaping (DispatchedAction<InputAction>, @escaping () -> State)
            -> Reader<Environment, Effect<OutputAction>>
    ) -> Self

    // Convenience when no environment is needed
    public static func handle(
        _ f: @escaping (DispatchedAction<InputAction>, @escaping () -> State)
            -> Effect<OutputAction>
    ) -> Self where Environment == Void
}
```

**FP structure — parallel/applicative Monoid (when symmetric):**

Both middlewares see the same `(action, state)`; their effects are merged via `Effect.append`. Order is preserved (lhs effects first in the merged stream).

```swift
extension Middleware: Monoid where InputAction == OutputAction {
    public static var identity: Self {
        .handle { _, _ in .pure(.empty) }
    }
    public static func append(_ lhs: Self, _ rhs: Self) -> Self {
        .handle { action, state in
            Effect.append(lhs.handle(action, state).run, rhs.handle(action, state).run)
            // Reader.append: pointwise Effect.append over the environment
        }
    }
}
```

**Per-axis transforms (FP-named):**
```swift
extension Middleware {
    public func contramapInputAction<GA>(
        _ f: @escaping (GA) -> InputAction?
    ) -> Middleware<GA, OutputAction, State, Environment>

    public func mapOutputAction<GOA>(
        _ f: @escaping (OutputAction) -> GOA
    ) -> Middleware<InputAction, GOA, State, Environment>

    public func contramapState<GS>(
        _ f: @escaping (GS) -> State
    ) -> Middleware<InputAction, OutputAction, GS, Environment>

    public func contramapEnvironment<GE>(
        _ f: @escaping (GE) -> Environment
    ) -> Middleware<InputAction, OutputAction, State, GE>
}
```

**`lift` — all combinations of the 4 axes:**

`lift` has overloads for every non-empty subset of the 4 axes (15 overloads, each with KeyPath and closure variants where applicable). Generated by Swift Macro to avoid hand-writing ~30 functions.

```swift
extension Middleware {
    // 4-axis (most common for library modules)
    public func lift<GA, GOA, GS, GE>(
        inputAction:  @escaping (GA) -> InputAction?,
        outputAction: @escaping (OutputAction) -> GOA,
        state:        @escaping (GS) -> State,
        environment:  @escaping (GE) -> Environment
    ) -> Middleware<GA, GOA, GS, GE>

    // KeyPath variant of the above
    public func lift<GA, GOA, GS, GE>(
        inputAction:  KeyPath<GA, InputAction?>,
        outputAction: @escaping (OutputAction) -> GOA,
        state:        KeyPath<GS, State>,
        environment:  @escaping (GE) -> Environment
    ) -> Middleware<GA, GOA, GS, GE>

    // … 13 more partial-combination overloads (macro-generated)
}
```

Optics overloads (`Prism<GA, InputAction>`, `Lens<GS, State>`) provided alongside KeyPath variants.

**Replacing `MiddlewareReader`:**

The old `MiddlewareReader<Deps, M>` is replaced by `Reader<Deps, Middleware<…>>` from the FP library, or a plain factory function `(Deps) -> Middleware<…>`. Library modules that don't know the app's environment type export a factory:

```swift
// In a feature library:
public func searchMiddleware()
    -> Reader<SearchDependencies, Middleware<AppAction, AppAction, AppState, SearchDependencies>>

// In the app — compose then inject:
let mw = searchMiddleware()
    .contramap { (appEnv: AppEnvironment) in appEnv.search }  // narrow environment
    .run(appEnv)                                               // materialise
```

---

### `ActionHandler<InputAction, OutputAction, State, Environment>`

The primary composition unit for feature modules. Unifies state mutation and effect production under a single `handle` closure — the direct form is its own definition, not a derived concept.

```swift
public struct ActionHandler<InputAction, OutputAction, State, Environment> {
    public let handle: (DispatchedAction<InputAction>, inout State)
        -> Reader<Environment, Effect<OutputAction>>
}
```

**Creating an `ActionHandler`:**

There are three equally valid ways to create one:

```swift
// 1. Direct closure — mutation and effect in one shot
let handler = ActionHandler<AppAction, AppAction, AppState, AppEnv>.handle { action, state in
    state.count += 1                          // mutate
    let snapshot = state.count
    return Reader { env in
        env.analytics.track("counted")        // environment access
        return .just(.didCount(snapshot))     // effect
    }
}

// 2. From a Reducer (effect is always .empty)
let handler = myReducer.asActionHandler

// 3. From a Reducer + Middleware combined
let handler = ActionHandler(reducer: myReducer, middleware: myMiddleware)
```

All three produce the same type. There is no preferred form — choose whichever expresses the intent most clearly.

**Temporal safety contract:**

The `inout State` parameter and the returned `Reader` enforce a strict temporal order:
1. `handle` is called — `inout State` mutations happen synchronously here
2. `handle` returns a `Reader` — state is no longer mutable; the closure captures a post-mutation snapshot
3. The Store resolves the `Reader` with the environment to obtain the `Effect`

Mutations and effects are structurally separated. An effect closure can never be interleaved with a state mutation because the mutation must complete before the `Reader` is returned. This is analogous to Elm's `update : Msg -> Model -> (Model, Cmd Msg)`, but without a state copy — `inout` means zero overhead.

**Named constructors:**
```swift
extension ActionHandler {
    // Primary form — full closure
    public static func handle(
        _ f: @escaping (DispatchedAction<InputAction>, inout State)
            -> Reader<Environment, Effect<OutputAction>>
    ) -> Self

    // Convenience — environment not needed
    public static func handle(
        _ f: @escaping (DispatchedAction<InputAction>, inout State)
            -> Effect<OutputAction>
    ) -> Self where Environment == Void

    // From a Reducer + Middleware pair
    public init(
        reducer:    Reducer<InputAction, State>,
        middleware: Middleware<InputAction, OutputAction, State, Environment>
    )
}
```

**Bridges from simpler types:**
```swift
extension Reducer {
    // Mutates state; always returns empty effect
    public var asActionHandler: ActionHandler<ActionType, ActionType, StateType, Void>
}

extension Middleware {
    // Reads state (no mutation); returns effect
    public var asActionHandler: ActionHandler<InputAction, OutputAction, State, Environment>
}
```

**FP structure — Monoid (when symmetric):**

State mutations are applied sequentially (lhs then rhs). Effects are merged in parallel.

```swift
extension ActionHandler: Monoid where InputAction == OutputAction {
    public static var identity: Self {
        .handle { _, _ in .pure(.empty) }
    }
    public static func combine(_ lhs: Self, _ rhs: Self) -> Self {
        .handle { action, state in
            let lhsReader = lhs.handle(action, &state)
            let rhsReader = rhs.handle(action, &state)
            return Reader { env in .combine(lhsReader.run(env), rhsReader.run(env)) }
        }
    }
}
```

**`lift` — same overload set as `Reducer` and `Middleware`, unified:**

A single `lift` call scopes the handler's local action, state, and environment types up to the global types. This is the mechanism that lets independently developed modules (each with their own `ActionHandler` at local types) be combined into one handler for the Store.

The overloads mirror `Reducer` exactly: `WritableKeyPath`, closure (`Lens(get:setMut:)`), optics (`Prism`, `Lens`, `AffineTraversal`), and all partial-axis combinations. The state axis uses `WritableKeyPath<GS, State>` (or optic equivalent) and performs in-place mutation via the modify coroutine — zero CoW overhead.

```swift
extension ActionHandler {
    // Representative 4-axis overload
    public func lift<GA, GOA, GS, GE>(
        inputAction:  KeyPath<GA, InputAction?>,
        outputAction: @escaping (OutputAction) -> GOA,
        state:        WritableKeyPath<GS, State>,
        environment:  @escaping (GE) -> Environment
    ) -> ActionHandler<GA, GOA, GS, GE>
    // … all non-empty subsets of 4 axes, KeyPath + closure + optics variants (macro-generated)
}
```

**`liftCollection`:** same overloads as `Reducer.liftCollection`; the per-element handler can also produce effects.

**The composition story — bringing everything to the Store's level:**

```swift
// Feature module: local types
let authHandler: ActionHandler<AuthAction, AuthAction, AuthState, AuthEnv> = …

// Wiring: lift to app-wide types, then combine
let appHandler: ActionHandler<AppAction, AppAction, AppState, AppEnv> =
    ActionHandler.combine(
        authHandler.lift(
            inputAction:  \AppAction.auth,
            outputAction: AppAction.auth,
            state:        \AppState.authState,
            environment:  \.auth
        ),
        profileHandler.lift(…)
    )

// Store needs one ActionHandler at <AppAction, AppAction, AppState, AppEnv>
let store = Store(initialState: .init(), actionHandler: appHandler, environment: env)
```

---

### `Store<Action, State, Environment>`

A `@MainActor actor` for data-race safety. Binding to the main actor is intentional — SwiftUI animation transactions are thread-local, so state mutation and observer notification must happen on the main thread for `withAnimation { }` to take effect.

```swift
@MainActor
public actor Store<Action, State, Environment> {
    private var _state: State
    private let actionHandler: ActionHandler<Action, Action, State, Environment>
    private let environment: Environment
    private var runningEffects: [AnyHashable: Cancellation] = [:]
    private var throttleTimestamps: [AnyHashable: /* clock instant */] = [:]
    private var observers: [UUID: (State) -> Void] = [:]

    // Primary initialiser — accepts a composed ActionHandler
    public init(
        initialState: State,
        actionHandler: ActionHandler<Action, Action, State, Environment>,
        environment: Environment
    )

    // Convenience — separate Reducer + Middleware, composed internally
    public init(
        initialState: State,
        reducer: Reducer<Action, State>,
        middleware: Middleware<Action, Action, State, Environment>,
        environment: Environment
    )

    public var currentState: State { _state }

    // Framework-free observation
    public func observe(_ handler: @escaping (State) -> Void) -> SubscriptionToken

    // Primary dispatch — synchronous from @MainActor callers; enqueued from other contexts
    public func dispatch(_ action: Action,
        file: String = #file, function: String = #function, line: UInt = #line)

    // Fire-and-forget from non-async / non-main-actor contexts
    public nonisolated func send(_ action: Action,
        file: String = #file, function: String = #function, line: UInt = #line)
}
```

**Dispatch flow:**
```
1. reader = actionHandler.handle(DispatchedAction(action, source), &_state)
             └─ inout _state: ALL mutations happen here, synchronously, atomically
2. notifyObservers()          — exactly once per action, after the full pipeline completes
3. effect = reader.run(environment)   — resolve Reader; effect sees post-mutation snapshot
4. scheduleEffect(effect)     — interpret EffectScheduling, run subscribe closure
   └─ produced DispatchedAction values loop back to step 1
```

**Atomic state notification — one notification per action:**

Observers always see fully-committed state, never an intermediate result from a partially-applied pipeline.

This is a structural guarantee, not a convention. Swift's Law of Exclusivity means that while `handle` holds `inout _state`, no other code can read or write `_state`. A composed `ActionHandler` (via `combine`) runs every handler's mutations sequentially inside a single `handle` call — the Store only regains access to `_state` once the entire call returns. `notifyObservers()` therefore always fires after every reducer and middleware in the pipeline has finished, regardless of how many are composed together.

Consequences:
- Views always receive consistent, fully-updated state snapshots.
- No observer ever sees a state where, say, the auth reducer has run but the profile reducer hasn't.
- The Store always notifies — fine-grained diffing is left to SwiftUI's `@Observable` tracking or to individual observer closures.

**SwiftUI animations:**

No framework API needed. Because `Store` is `@MainActor` and `dispatch` is synchronous from any `@MainActor` caller, SwiftUI views can wrap dispatches directly:

```swift
Button("Add") {
    withAnimation(.spring()) {
        store.dispatch(.addItem)
    }
}
```

`notifyObservers()` fires synchronously inside the `withAnimation` block on the same RunLoop tick — SwiftUI sees the state change in the right transaction context and schedules animated transitions. Animation stays entirely in the view layer, where it belongs. The Store, Effect, and all framework types remain unaware of SwiftUI animations.

The Store always notifies after a dispatch — fine-grained diffing is left to SwiftUI's `@Observable` tracking or to individual observer closures.

**Effect scheduling (all mutable state lives here, not in Middleware):**

| `EffectScheduling` | Store behaviour |
|---|---|
| `.immediately` | call `_subscribe` now, store `Cancellation` transiently |
| `.cancellable(id)` | cancel previous for same id, call `_subscribe`, store new `Cancellation` |
| `.debounce(id, delay)` | cancel pending, start a delayed task, run if not cancelled before expiry |
| `.throttle(id, interval)` | skip if same id ran within interval; record timestamp |
| `.cancelInFlight(id)` | call `cancel()` on stored `Cancellation`, remove from dict |

**State observation bridges (in respective targets):**
```swift
// CombineRex
extension Store {
    public var statePublisher: AnyPublisher<State, Never> { … }
}

// CombineRex + SwiftUI
// iOS 13+: ObservableObject wrapper
// iOS 17+: @Observable wrapper

// RxSwiftRex
extension Store {
    public var stateObservable: Observable<State> { … }
}

// ReactiveSwiftRex
extension Store {
    public var stateSignalProducer: SignalProducer<State, Never> { … }
}
```

---

### `StoreProjection<LocalAction, LocalState>`

The boundary between domain state and view state. It maps global `State → LocalState` and is where `@Observable` / `ObservableObject` conformance lives — not on the `Store`.

**Why here and not on `Store`:**

The Store always notifies after every dispatch (no deduplication, no copies). Deduplication only makes sense on the *view state* — the mapped slice. Consider:

```
Domain state:  price = 1.234  →  price = 1.235   (changed at third decimal)
View state:    priceString = "1.23"  →  "1.23"   (same after formatting)
```

The Store correctly fires because domain state changed. `StoreProjection` computes the new `LocalState`, finds it equal to the previous one, and silently skips the SwiftUI update — no re-render.

This requires `LocalState: Equatable`, which is a reasonable constraint: view state is typically a small, flat struct that the view renders directly.

**`StoreProjection` is a class, not a struct** — it must hold the previous `LocalState` to compare, subscribe to the Store, and own the `SubscriptionToken`. It is `@MainActor`-bound, matching the Store.

**`@Observable` variant (iOS 17+):**

```swift
@MainActor @Observable
public final class StoreProjection<LocalAction, LocalState: Equatable> {
    public private(set) var viewState: LocalState
    private var token: SubscriptionToken?

    public init<GlobalAction, GlobalState, Environment>(
        store: Store<GlobalAction, GlobalState, Environment>,
        action: @escaping (LocalAction) -> GlobalAction,
        state:  @escaping (GlobalState) -> LocalState
    ) {
        viewState = state(store.currentState)
        token = store.observe { [weak self] newGlobalState in
            let newViewState = state(newGlobalState)
            guard newViewState != self?.viewState else { return }
            self?.viewState = newViewState   // triggers @Observable tracking
        }
    }

    public func dispatch(_ action: LocalAction) { … }
}
```

`@Observable` provides sub-property tracking: if `LocalState` has multiple fields and only `priceString` changed, only views that read `projection.viewState.priceString` re-render. The `Equatable` guard prevents even that when the whole `LocalState` hasn't changed.

**`ObservableObject` variant (iOS 13–16):**

```swift
@MainActor
public final class StoreProjection<LocalAction, LocalState: Equatable>: ObservableObject {
    @Published public private(set) var viewState: LocalState
    // same init and guard logic
}
```

Coarser — `objectWillChange` fires for any `viewState` change — but the `Equatable` guard still prevents spurious updates when domain state changes but view state doesn't.

**The performance story end-to-end:**

| Layer | Copies | Diffing |
|---|---|---|
| `ActionHandler.handle` | zero (inout) | none |
| `Store.notifyObservers()` | zero | none — always fires |
| `StoreProjection` | one `LocalState` value per notification | `Equatable` on the small view state |
| SwiftUI (`@Observable`) | none | sub-property tracking per view |

Domain state never needs to be `Equatable` or copied for comparison purposes.

#### Collection element scoping

For SwiftUI `ForEach`, create one `StoreProjection` per element. The projected `LocalState` is `Element?` because the element may be removed while the view is still live.

```swift
ForEach(store.currentState.items) { item in
    ItemView(projection: StoreProjection(
        store: store,
        action: { AppAction.item(id: item.id, action: $0) },
        state:  { $0.items.first(where: { $0.id == item.id }) }
    ))
}
```

Factory overloads on `Store` for the common collection cases:

```swift
extension Store {
    // Identifiable element
    public func projection<LA, LS: Equatable, C: Collection>(
        action: @escaping (LA) -> Action,
        stateCollection: KeyPath<State, C>,
        elementId: C.Element.ID,
        viewState: @escaping (C.Element?) -> LS
    ) -> StoreProjection<LA, LS> where C.Element: Identifiable

    // Custom Hashable identifier
    public func projection<LA, LS: Equatable, C: Collection, ID: Hashable>(
        action: @escaping (LA) -> Action,
        stateCollection: KeyPath<State, C>,
        elementId: ID,
        identifier: KeyPath<C.Element, ID>,
        viewState: @escaping (C.Element?) -> LS
    ) -> StoreProjection<LA, LS>
}
```

---

## What Changed vs. Previous SwiftRex

| Removed | Replaced by |
|---|---|
| `MiddlewareProtocol` | `Middleware<In, Out, S, E>` struct |
| `IO<Action>` | `Effect<Action>` (push-based, lazy, opaque) |
| `MiddlewareReader<Deps, M>` | `Reader<Deps, Middleware<…>>` from FP library |
| `EffectMiddleware` (per-framework classes) | `Middleware` struct + bridge factories |
| `ReduxStoreBase` class | `Store` actor |
| `ReduxPipelineWrapper` | inline dispatch flow in `Store` |
| `PublisherType` / `SubscriberType` / `SubjectType` | eliminated from core; live only in bridge targets |
| `ComposedMiddleware` struct | `Middleware.append` (Monoid) |
| `LiftMiddleware` struct | `Middleware.lift(…)` |
| `IdentityMiddleware` | `Middleware.identity` |
| `AnyMiddleware` | reconsidered; may keep for heterogeneous storage |
| `receiveContext` | deleted (was already deprecated) |
| ASAP scheduler | actor isolation handles serialisation |
| Sourcery code generation | Swift Macros |

## What Is Kept

- `Reducer<Action, State>` — same `inout` signature, same lift API, now with FP naming aliases
- `ActionSource` / `DispatchedAction<Action>` — call-site tracing
- `liftToCollection` variants (Identifiable, custom ID, index)
- `<>` operator — in `SwiftRexOperators` only
- KeyPath-based `lift` — primary ergonomic API
- Optics-based `lift` — secondary API for composable power users

---

## Implementation Order

1. ✅ `Package.swift` — products, targets, FP dependency, platform minimums
2. ✅ Foundation — `ActionSource`, `DispatchedAction`, `SubscriptionToken`, `ElementAction`
3. ✅ `Reducer` — inout/pure factories, FP Monoid, `@ReducerBuilder` DSL, full `lift`/`liftCollection` overloads
4. `Effect` — push-based subscribe closure, `EffectScheduling`, factories, Functor, Monoid
5. `Middleware` — struct, Reader-returning `handle`, Monoid, per-axis transforms, `lift` overloads
6. `ActionHandler` — bundles Reducer + Middleware; `asActionHandler` bridges; Monoid; `lift`/`liftCollection`
7. `Store` — `@MainActor actor`, ActionHandler-based dispatch flow, effect scheduling, push-based `observe`
8. `StoreProjection` — class, `State → LocalState` mapping, `Equatable` deduplication, `@Observable` (iOS 17+) and `ObservableObject` (iOS 13+) variants; this is where SwiftUI observation lives, not on `Store`
9. `CombineRex` bridges — `Effect+Publisher`, `Store+Publisher`
10. `RxSwiftRex` bridges
11. `ReactiveSwiftRex` bridges
12. `SwiftRexOperators` — `<>` and other symbolic operators via FP operator modules
13. Swift Macro for `lift` overload generation
14. Tests for each layer
