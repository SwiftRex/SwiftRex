import CoreFP

/// A pure function that calculates a new state given an action and the current state.
///
/// Reducers are the only place in SwiftRex that is allowed to mutate `State`. They are completely
/// pure — no side effects, no async work, no environment access. Side effects belong in
/// `Middleware` and are expressed as `Effect` values.
///
/// The internal representation is `(Action, inout State) -> Void` rather than the functional
/// `(Action, State) -> State` to avoid unnecessary copies of large state trees. A second overload
/// of `reduce` accepts the functional form and bridges it automatically.
///
/// `Reducer` is a **Semigroup** and **Monoid** under sequential composition: `combine(a, b)` runs
/// `a` then `b` on the same `inout State`, so `b` sees `a`'s mutations. Order matters.
public struct Reducer<ActionType, StateType> {
    /// The underlying reduce function.
    public let reduce: (ActionType, inout StateType) -> Void

    init(reduce: @escaping (ActionType, inout StateType) -> Void) {
        self.reduce = reduce
    }
}

// MARK: - Constructors

extension Reducer {
    /// Creates a `Reducer` from an `inout` mutation function — the primary form.
    public static func reduce(_ f: @escaping (ActionType, inout StateType) -> Void) -> Reducer {
        Reducer(reduce: f)
    }

    /// Creates a `Reducer` from a functional `(Action, State) -> State` — bridges to `inout` internally.
    ///
    /// Prefer the `inout` overload for large state trees to avoid copies. Use this form when
    /// working with immutable value pipelines or when expressing the reducer as a transformation:
    /// ```swift
    /// Reducer.reduce { action, state in
    ///     switch action {
    ///     case .increment: State(count: state.count + 1)
    ///     }
    /// }
    /// ```
    public static func reduce(_ f: @escaping (ActionType, StateType) -> StateType) -> Reducer {
        .reduce { action, state in state = f(action, state) }
    }
}

// MARK: - Semigroup & Monoid

extension Reducer: Semigroup {
    /// Sequential composition: runs `lhs` then `rhs` on the same `inout State`.
    ///
    /// `rhs` observes any mutations made by `lhs`. The composition is associative but not
    /// commutative — order matters.
    public static func combine(_ lhs: Reducer, _ rhs: Reducer) -> Reducer {
        .reduce { action, state in
            lhs.reduce(action, &state)
            rhs.reduce(action, &state)
        }
    }
}

extension Reducer: Monoid {
    /// The no-op reducer. Composing with `identity` leaves the other reducer unchanged.
    public static var identity: Reducer {
        .reduce(untuple(\.1))
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
    ///     // Each reducer is scoped to its own action/state subset via lift.
    ///     // They run in the order listed; mutations are visible to subsequent reducers.
    ///     authReducer
    ///         .lift(action: \.auth, state: \.authState)
    ///
    ///     profileReducer
    ///         .lift(action: \.profile, state: \.profileState)
    ///
    ///     Reducer.reduce { action, state in
    ///         // An inline reducer can appear anywhere in the list.
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
