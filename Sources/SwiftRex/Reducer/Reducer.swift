import CoreFP

/// A pure function that calculates a new state given an action and the current state.
///
/// Reducers are the only place in SwiftRex that is allowed to mutate `State`. They are completely
/// pure — no side effects, no async work, no environment access. Side effects belong in
/// `Middleware` and are expressed as `Effect` values.
///
/// Internally a `Reducer` stores `(ActionType) -> EndoMut<StateType>`: given an action it produces
/// an in-place endomorphism on `State`. This representation makes the monoidal structure of
/// `Reducer` a direct, pointwise lift of `EndoMut`'s `Monoid`: combining two reducers combines
/// their `EndoMut` values for each action, keeping a single allocation path through the pipeline.
///
/// The Store calls `reducer.reduce(action).runEndoMut(&_state)` in its dispatch pipeline.
///
/// `Reducer` is a **Semigroup** and **Monoid** under sequential composition: `combine(a, b)` runs
/// `a` then `b` on the same `inout State`, so `b` sees `a`'s mutations. Order matters.
public struct Reducer<ActionType, StateType>: @unchecked Sendable {
    /// Given an action, produces an in-place endomorphism on `StateType`.
    ///
    /// The Store uses this as `reduce(action).runEndoMut(&_state)`.
    public let reduce: (ActionType) -> EndoMut<StateType>

    private init(_ reduce: @escaping (ActionType) -> EndoMut<StateType>) {
        self.reduce = reduce
    }
}

// MARK: - Constructors

extension Reducer {
    /// Creates a `Reducer` from `(Action) -> EndoMut<State>` — the primary internal form.
    ///
    /// Use this when you already have an `EndoMut` per action, or when composing with other
    /// `EndoMut`-based pipelines. The closure is stored directly with no bridging overhead.
    public static func reduce(_ f: @escaping (ActionType) -> EndoMut<StateType>) -> Reducer {
        Reducer(f)
    }

    /// Creates a `Reducer` from `(Action) -> Endo<State>`. Bridges via `.toEndoMut()`.
    ///
    /// Use this when the transformation is naturally expressed as a pure `(State) -> State`
    /// function per action. One `Endo → EndoMut` bridge is applied per action dispatch.
    public static func reduce(_ f: @escaping (ActionType) -> Endo<StateType>) -> Reducer {
        Reducer { action in f(action).toEndoMut() }
    }

    /// Creates a `Reducer` from an `inout` mutation function — the idiomatic Swift form.
    ///
    /// Mutating `state` directly avoids copying large value trees. Use this for most leaf
    /// reducers:
    /// ```swift
    /// Reducer.reduce { action, state in
    ///     switch action {
    ///     case .increment: state += 1
    ///     case .reset:     state = 0
    ///     }
    /// }
    /// ```
    public static func reduce(_ f: @escaping (ActionType, inout StateType) -> Void) -> Reducer {
        Reducer { action in EndoMut { state in f(action, &state) } }
    }

    /// Creates a `Reducer` from a pure `(Action, State) -> State` function. Bridges via
    /// `Endo.toEndoMut()`.
    ///
    /// Prefer the `inout` overload for large mutable state trees. Use this form when the new
    /// state is naturally expressed as a whole-value transformation:
    /// ```swift
    /// Reducer.reduce { action, state in
    ///     switch action {
    ///     case .updateName(let n): ProfileState.lens.name.set(state, n)
    ///     }
    /// }
    /// ```
    public static func reduce(_ f: @escaping (ActionType, StateType) -> StateType) -> Reducer {
        Reducer { action in Endo { state in f(action, state) }.toEndoMut() }
    }
}

// MARK: - Semigroup & Monoid

extension Reducer: Semigroup {
    /// Sequential composition: for each action, combines the two `EndoMut` values pointwise.
    ///
    /// `rhs` observes any mutations made by `lhs`. The composition is associative but not
    /// commutative — order matters.
    public static func combine(_ lhs: Reducer, _ rhs: Reducer) -> Reducer {
        Reducer { action in .combine(lhs.reduce(action), rhs.reduce(action)) }
    }
}

extension Reducer: Monoid {
    /// The no-op reducer. Composing with `identity` leaves the other reducer unchanged.
    ///
    /// For every action it returns `EndoMut.identity` — the do-nothing in-place closure.
    public static var identity: Reducer {
        .reduce { _ in EndoMut<StateType>.identity }
    }
}

// MARK: - DSL Builder

/// Enables the ``Reducer/compose(content:)`` DSL syntax for listing reducers in a block.
///
/// Each line in the block is an independent `Reducer` value. They are collected and folded
/// left-to-right via ``Reducer/combine(_:_:)``, so each reducer sees the state mutations
/// made by all preceding ones.
///
/// ## Using `@ReducerBuilder` as a function attribute
///
/// Like `@ViewBuilder` in SwiftUI, you can annotate your own functions, computed properties,
/// or initialiser parameters with `@ReducerBuilder` to make their body a reducer-composition
/// block — without needing to call ``Reducer/compose(content:)`` explicitly:
///
/// ```swift
/// // Computed property — @ReducerBuilder on the property, just like @ViewBuilder on `body`
/// extension ProfileModule {
///     @ReducerBuilder
///     var reducer: Reducer<ProfileAction, ProfileState> {
///         avatarReducer
///         bioReducer
///         settingsReducer.lift(action: \.settings, state: \.settings)
///     }
/// }
///
/// // Static factory — useful when construction needs parameters
/// extension AuthModule {
///     @ReducerBuilder
///     static func reducer(config: AuthConfig) -> Reducer<AuthAction, AuthState> {
///         loginReducer(config: config)
///         logoutReducer
///         tokenRefreshReducer
///     }
/// }
///
/// // Composing at the app level from module factories
/// let appReducer: Reducer<AppAction, AppState> = Reducer.compose {
///     AuthModule.reducer(config: .production).lift(action: \.auth, state: \.authState)
///     ProfileModule().reducer.lift(action: \.profile, state: \.profileState)
/// }
/// ```
///
/// You never use `ReducerBuilder` directly — it is the backing machinery for the `@ReducerBuilder`
/// parameter in ``Reducer/compose(content:)``.
@resultBuilder public enum ReducerBuilder {
    public static func buildBlock<Action, State>(
        _ reducers: Reducer<Action, State>...
    ) -> Reducer<Action, State> {
        mconcat(reducers)
    }
}

extension Reducer {
    /// Composes reducers sequentially using a DSL block.
    ///
    /// Each reducer listed in the block handles the same incoming action against the same
    /// `State`, but in order — the second reducer sees any mutations made by the first, and so on.
    /// This is monoidal composition (`mconcat`) written in a readable top-to-bottom style.
    ///
    /// Prefer this form when composing many reducers, or when the composition reads more clearly
    /// as a vertical list than a chain of ``combine(_:_:)`` calls.
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
    /// An empty block produces ``identity`` — the no-op reducer.
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
    public static func compose(_ first: Reducer, _ others: Reducer...) -> Reducer {
        sconcat(first, others)
    }
}
