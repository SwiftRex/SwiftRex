import CoreFP

/// A pure function that calculates how state should change in response to an action.
///
/// A `Reducer` is the only place in SwiftRex that is allowed to mutate `State`. It is completely
/// pure — no side effects, no async work, no environment access. Side effects belong in
/// ``Middleware`` and are expressed as ``Effect`` values returned from ``Behavior``.
///
/// ## Internal representation
///
/// Internally a `Reducer` stores `(ActionType) -> EndoMut<StateType>`: given an action, it
/// returns an in-place endomorphism on `State`. This representation:
///
/// - Avoids copying state on every action — mutations are applied directly via `inout`.
/// - Makes the `Monoid` structure a direct, pointwise lift of `EndoMut`'s `Monoid`.
/// - Keeps composition associative and free of allocation overhead.
///
/// The ``Store`` calls `reducer.reduce(action).runEndoMut(&_state)` during phase 2 of dispatch.
///
/// ## Constructors
///
/// Four factory overloads cover the most common use cases:
///
/// ```swift
/// // 1. Idiomatic Swift — direct inout mutation (preferred for leaf reducers)
/// let counter = Reducer<CounterAction, Int>.reduce { action, state in
///     switch action {
///     case .increment: state += 1
///     case .decrement: state -= 1
///     case .reset:     state  = 0
///     }
/// }
///
/// // 2. From a pure (Action, State) -> State function
/// let toggle = Reducer<ToggleAction, Bool>.reduce { action, state in
///     switch action {
///     case .toggle: !state
///     }
/// }
///
/// // 3. From (Action) -> EndoMut<State> — for low-level composition
/// let raw = Reducer<MyAction, MyState>.reduce { action in
///     EndoMut { state in /* ... */ }
/// }
///
/// // 4. From (Action) -> Endo<State> — when the new state is a pure function
/// let endo = Reducer<MyAction, MyState>.reduce { action in
///     Endo { state in /* return new state */ }
/// }
/// ```
///
/// ## Composition with `@ReducerBuilder`
///
/// ```swift
/// let appReducer: Reducer<AppAction, AppState> = Reducer.compose {
///     authReducer.lift(action: \.auth, state: \.authState)
///     profileReducer.lift(action: \.profile, state: \.profileState)
/// }
/// ```
///
/// ## Semigroup & Monoid
///
/// `Reducer` is a **Semigroup** under sequential composition and a **Monoid** with
/// ``identity`` as the neutral element. `combine(a, b)` runs `a`'s mutation then `b`'s on
/// the same `inout State`, so `b` observes `a`'s changes.
///
/// - Note: `@unchecked Sendable` is used because `ActionType` and `StateType` do not have a
///   `Sendable` constraint at the type level, but the stored closure is always called on
///   `@MainActor`, making it safe in practice.
public struct Reducer<ActionType, StateType>: @unchecked Sendable {
    /// Given an action, produces an in-place endomorphism on `StateType`.
    ///
    /// The ``Store`` uses this as `reduce(action).runEndoMut(&_state)` in phase 2 of
    /// dispatch. The resulting `EndoMut` captures the action and modifies the state
    /// in-place when run.
    public let reduce: (ActionType) -> EndoMut<StateType>

    private init(_ reduce: @escaping (ActionType) -> EndoMut<StateType>) {
        self.reduce = reduce
    }
}

// MARK: - Constructors

extension Reducer {
    /// Creates a `Reducer` from `(Action) -> EndoMut<State>` — the primary internal form.
    ///
    /// Use this when you already have an `EndoMut` per action or when composing with other
    /// `EndoMut`-based pipelines. The closure is stored directly with no bridging overhead.
    ///
    /// ```swift
    /// let myReducer = Reducer<MyAction, MyState>.reduce { action in
    ///     EndoMut { state in
    ///         switch action {
    ///         case .reset: state = .initial
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter f: A function from action to `EndoMut<State>`.
    /// - Returns: A `Reducer` that applies the returned `EndoMut` for each action.
    public static func reduce(_ f: @escaping (ActionType) -> EndoMut<StateType>) -> Reducer {
        Reducer(f)
    }

    /// Creates a `Reducer` from `(Action) -> Endo<State>`. Bridges via `.toEndoMut()`.
    ///
    /// Use this when the transformation is naturally expressed as a pure `(State) -> State`
    /// function per action. One `Endo → EndoMut` bridge is applied on each action dispatch.
    ///
    /// - Parameter f: A function from action to `Endo<State>` (a `State -> State` function).
    /// - Returns: A `Reducer` that converts each `Endo` to an `EndoMut` via `.toEndoMut()`.
    public static func reduce(_ f: @escaping (ActionType) -> Endo<StateType>) -> Reducer {
        Reducer { action in f(action).toEndoMut() }
    }

    /// Creates a `Reducer` from an `inout` mutation function — the idiomatic Swift form.
    ///
    /// Mutating `state` directly avoids copying large value trees. This overload is the
    /// preferred choice for most leaf reducers:
    ///
    /// ```swift
    /// let counterReducer = Reducer<CounterAction, CounterState>.reduce { action, state in
    ///     switch action {
    ///     case .increment:       state.count += 1
    ///     case .decrement:       state.count -= 1
    ///     case .reset:           state.count  = 0
    ///     case .setMax(let max): state.max    = max
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter f: A closure that receives the action and mutates `state` in place.
    /// - Returns: A `Reducer` that wraps each `inout` mutation in an `EndoMut`.
    public static func reduce(_ f: @escaping (ActionType, inout StateType) -> Void) -> Reducer {
        Reducer { action in EndoMut { state in f(action, &state) } }
    }

    /// Creates a `Reducer` from a pure `(Action, State) -> State` function.
    /// Bridges via `Endo.toEndoMut()`.
    ///
    /// Use this form when the new state is naturally expressed as a whole-value
    /// transformation — for example, when using computed properties or optics:
    ///
    /// ```swift
    /// let nameReducer = Reducer<ProfileAction, ProfileState>.reduce { action, state in
    ///     switch action {
    ///     case .updateName(let n): ProfileState.lens.name.set(state, n)
    ///     default: state
    ///     }
    /// }
    /// ```
    ///
    /// - Note: This form copies `state` on every action dispatch. Prefer the `inout` overload
    ///   for large mutable state trees.
    ///
    /// - Parameter f: A pure function from `(ActionType, StateType)` to a new `StateType`.
    /// - Returns: A `Reducer` that bridges each invocation through `Endo.toEndoMut()`.
    public static func reduce(_ f: @escaping (ActionType, StateType) -> StateType) -> Reducer {
        Reducer { action in Endo { state in f(action, state) }.toEndoMut() }
    }
}

// MARK: - Semigroup & Monoid

extension Reducer: Semigroup {
    /// Sequential composition: for each action, runs `lhs`'s mutation then `rhs`'s on the same
    /// `inout State`.
    ///
    /// `rhs` observes any mutations made by `lhs`. Composition is associative but not
    /// commutative — order matters. Use ``compose(content:)`` or ``ReducerBuilder`` for
    /// readable multi-reducer composition.
    ///
    /// - Parameters:
    ///   - lhs: The first reducer; its mutation runs first.
    ///   - rhs: The second reducer; its mutation sees lhs's changes.
    /// - Returns: A reducer whose `EndoMut` is the sequential composition of both.
    public static func combine(_ lhs: Reducer, _ rhs: Reducer) -> Reducer {
        Reducer { action in .combine(lhs.reduce(action), rhs.reduce(action)) }
    }
}

extension Reducer: Monoid {
    /// The no-op reducer — for every action it returns `EndoMut.identity` (do nothing).
    ///
    /// Composing with `identity` leaves the other reducer unchanged.
    /// An empty ``compose(content:)`` block also produces this.
    public static var identity: Reducer {
        .reduce { _ in EndoMut<StateType>.identity }
    }
}

// MARK: - DSL Builder

/// A result builder that collects `Reducer` values from a block and folds them left-to-right
/// via ``Reducer/combine(_:_:)``, enabling a SwiftUI-style DSL for reducer composition.
///
/// Each line in the block is an independent `Reducer` value. They are composed so that each
/// reducer sees the state mutations made by all preceding reducers in the block.
///
/// ## Using `@ReducerBuilder` as a function attribute
///
/// Like `@ViewBuilder` in SwiftUI, annotate computed properties, functions, or initialiser
/// parameters with `@ReducerBuilder` to make their body a reducer-composition block:
///
/// ```swift
/// // Computed property — mirrors the @ViewBuilder `body` pattern
/// extension ProfileModule {
///     @ReducerBuilder
///     var reducer: Reducer<ProfileAction, ProfileState> {
///         avatarReducer
///         bioReducer
///         settingsReducer.lift(action: \.settings, state: \.settings)
///     }
/// }
///
/// // Static factory with parameters
/// extension AuthModule {
///     @ReducerBuilder
///     static func reducer(config: AuthConfig) -> Reducer<AuthAction, AuthState> {
///         loginReducer(config: config)
///         logoutReducer
///         tokenRefreshReducer
///     }
/// }
/// ```
///
/// You never use `ReducerBuilder` directly — it is the backing machinery for the
/// `@ReducerBuilder` parameter in ``Reducer/compose(content:)``.
///
/// - SeeAlso: ``Reducer/compose(content:)``, ``Reducer/combine(_:_:)``
@resultBuilder public enum ReducerBuilder {
    /// Collects all `Reducer` values from the block and folds them with `mconcat`.
    ///
    /// - Parameter reducers: The reducers listed in the builder block.
    /// - Returns: A single `Reducer` that is the sequential composition of all inputs.
    public static func buildBlock<Action, State>(
        _ reducers: Reducer<Action, State>...
    ) -> Reducer<Action, State> {
        mconcat(reducers)
    }
}

extension Reducer {
    /// Composes reducers sequentially using a `@ReducerBuilder` block.
    ///
    /// Each reducer listed in the block handles the same incoming action against the same
    /// `State`, but in order — each reducer sees the state mutations made by all preceding
    /// ones. This is monoidal composition (`mconcat`) in a readable top-to-bottom style.
    ///
    /// An empty block produces ``identity`` — the no-op reducer.
    ///
    /// ```swift
    /// let appReducer: Reducer<AppAction, AppState> = Reducer.compose {
    ///     authReducer
    ///         .lift(action: \.auth, state: \.authState)
    ///
    ///     profileReducer
    ///         .lift(action: \.profile, state: \.profileState)
    ///
    ///     Reducer.reduce { action, state in
    ///         if case .resetAll = action { state = .initial }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter content: A `@ReducerBuilder` block listing reducers to compose.
    /// - Returns: The sequential composition of all reducers in the block.
    public static func compose(@ReducerBuilder content: () -> Reducer) -> Reducer {
        content()
    }

    /// Composes two or more reducers sequentially using variadic arguments.
    ///
    /// Equivalent to ``compose(content:)`` but written inline. Prefer the DSL form when
    /// composing more than two or three reducers for readability.
    ///
    /// ```swift
    /// let appReducer = Reducer.compose(
    ///     authReducer.lift(action: \.auth, state: \.authState),
    ///     profileReducer.lift(action: \.profile, state: \.profileState)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - first: The first reducer (required so the overload does not conflict with `compose(content:)`).
    ///   - others: Additional reducers to compose in order.
    /// - Returns: The sequential composition of `first` followed by each element of `others`.
    public static func compose(_ first: Reducer, _ others: Reducer...) -> Reducer {
        sconcat(first, others)
    }
}
