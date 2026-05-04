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
    │   │   ├── Cancellation.swift
    │   │   ├── ActionSource.swift
    │   │   ├── DispatchedAction.swift
    │   │   └── ShouldEmitValue.swift
    │   ├── Core/
    │   │   ├── Reducer.swift
    │   │   ├── Effect.swift
    │   │   ├── Middleware.swift
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

### `ShouldEmitValue<State>`

Controls when the Store notifies observers after a state mutation. Does not require `Equatable`.

```swift
public enum ShouldEmitValue<State> {
    case always
    case never
    case when((State, State) -> Bool)
}
```

Rationale: Combine's `removeDuplicates()` has had correctness bugs historically. Keeping deduplication in-house gives full control without forcing `Equatable` on `State`.

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

**ZIO as an advanced layer:**

`ZIO<Env, Log, Result>` from the FP library (Env = Environment, Log = `Effect<Action>`, Result = State) can represent the full pipeline as a single monad stack: `(Action, State) -> ZIO<Environment, Effect<Action>, State>`. This is mathematically equivalent to Reducer + Middleware combined. It is **not** the primary API but is documented as an advanced composition option with bridge functions provided.

---

### `Store<Action, State, Environment>`

The only class-like entity in the system. An `actor` for Swift-concurrency data-race safety. Owns all mutable state: current state, running effect tasks, debounce/throttle timestamps, and state observer callbacks.

```swift
public actor Store<Action, State, Environment> {
    private var _state: State
    private let reducer: Reducer<Action, State>
    private let middleware: Middleware<Action, Action, State, Environment>
    private let environment: Environment
    private let shouldEmit: ShouldEmitValue<State>

    // Running effects keyed by cancellation id
    private var runningEffects: [AnyHashable: Cancellation] = [:]
    private var throttleTimestamps: [AnyHashable: /* clock instant */] = [:]

    // Push-based state observers
    private var observers: [UUID: (State) -> Void] = [:]

    public init(
        initialState: State,
        reducer: Reducer<Action, State>,
        middleware: Middleware<Action, Action, State, Environment>,
        environment: Environment,
        emitsValue: ShouldEmitValue<State> = .always
    )

    public var currentState: State { _state }

    // Framework-free state observation
    public func observe(_ handler: @escaping (State) -> Void) -> Cancellation

    // Primary dispatch (actor-isolated)
    public func dispatch(_ action: Action,
        file: String = #file, function: String = #function, line: UInt = #line)

    // Fire-and-forget wrapper for use from non-async contexts (SwiftUI, UIKit)
    public nonisolated func send(_ action: Action,
        file: String = #file, function: String = #function, line: UInt = #line)
}
```

**Dispatch flow:**
```
1. reader  = middleware.handle(DispatchedAction(action, source), { _state })
2. effect  = reader.run(environment)          — resolves Reader → Effect
3. reducer.reduce(action, &_state)            — pure state mutation
4. notifyObservers()                          — push to all registered handlers
5. scheduleEffect(effect)                     — interpret EffectScheduling, run subscribe closure
   └─ produced DispatchedAction values loop back to step 1
```

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

A lightweight stateless struct that maps a slice of the Store for use in a specific screen or component. Holds only the mapping closures — no state, no ownership.

```swift
public struct StoreProjection<LocalAction, LocalState> {
    public let dispatch: (LocalAction) -> Void
    public let observe: (@escaping (LocalState) -> Void) -> Cancellation
}

extension Store {
    public func projection<LA, LS>(
        action: @escaping (LA) -> Action,
        state:  @escaping (State) -> LS
    ) -> StoreProjection<LA, LS>
}
```

#### Collection element scoping

For SwiftUI `ForEach`, `StoreProjection` needs a way to scope to a single element identified
by ID. The goal is standard SwiftUI `ForEach` — no custom `ForEachStore` wrapper — where each
row receives its own `StoreProjection` scoped to one element:

```swift
ForEach(store.state.items) { item in
    ItemView(store: store.projection(
        action: { .item(id: item.id, action: $0) },
        stateCollection: \.items,
        elementId: item.id,
        identifier: \.id
    ))
}
```

The projected state is `Element?` (optional) because the element may be removed while the
view is still live. The view is responsible for handling nil (fade out, dismiss, ignore).

```swift
extension Store {
    // Identifiable elements
    public func projection<LA, C: Collection>(
        action: @escaping (LA) -> Action,
        stateCollection: KeyPath<State, C>,
        elementId: C.Element.ID
    ) -> StoreProjection<LA, C.Element?> where C.Element: Identifiable

    // Custom Hashable identifier
    public func projection<LA, C: Collection, ID: Hashable>(
        action: @escaping (LA) -> Action,
        stateCollection: KeyPath<State, C>,
        elementId: ID,
        identifier: KeyPath<C.Element, ID>
    ) -> StoreProjection<LA, C.Element?>
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
- `ShouldEmitValue<State>` — user-controlled state emission predicate
- `liftToCollection` variants (Identifiable, custom ID, index)
- `<>` operator — in `SwiftRexOperators` only
- KeyPath-based `lift` — primary ergonomic API
- Optics-based `lift` — secondary API for composable power users

---

## Implementation Order

1. `Package.swift` — products, targets, FP dependency, platform minimums
2. `Cancellation`, `ActionSource`, `DispatchedAction`, `ShouldEmitValue`
3. `Reducer` — merge from `github.com/SwiftRex/Reducer`, add FP Monoid conformance, add `contramap`/`dimap` naming, add `pure` factory
4. `Effect` — push-based subscribe closure, `Cancellation`, `EffectScheduling`, factories, Functor, Monoid
5. `Middleware` — struct, Reader-returning `handle`, Monoid, per-axis transforms, `lift` overloads
6. `Store` — actor, dispatch flow, effect scheduling, push-based `observe`
7. `StoreProjection`
8. `CombineRex` bridges — `Effect+Publisher`, `Store+Publisher`, `ObservableViewModel`, `ObservableStore`
9. `RxSwiftRex` bridges
10. `ReactiveSwiftRex` bridges
11. `SwiftRexOperators` — `<>` and other symbolic operators via FP operator modules
12. Swift Macro for `lift` overload generation
13. Tests for each layer
