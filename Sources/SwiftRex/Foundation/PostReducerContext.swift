/// A `Sendable` context injected into ``Behavior`` and ``Middleware`` effect closures during
/// phase 3 of dispatch (post-mutation).
///
/// `PostReducerContext` is the environment type for `Reader<PostReducerContext<State, Environment>, Effect<Action>>`.
/// It replaces the bare `Environment` value with a richer record that includes both:
///
/// - ``environment``: the store's injected dependencies — accessible synchronously, from any
///   context, without `await`.
/// - ``stateAfter``: the state **after** all `EndoMut` values from this dispatch cycle ran.
///   It is `@MainActor`, so a non-`@MainActor` effect must hop to the main actor
///   (or use the Combine / RxSwift `readStateAfter()` helpers) to read it.
///
/// ## Usage
///
/// ```swift
/// // Middleware — access environment and post-mutation state
/// Middleware<AppAction, AppState, API>.handle { action, _ in
///     guard case .load(let id) = action else { return .doNothing }
///     return Reader { ctx in
///         ctx.environment.api.fetch(id: id).asEffect()
///     }
/// }
///
/// // Behavior — both mutation and effect
/// Behavior<AppAction, AppState, API> { action, _ in
///     guard case .submit(let form) = action else { return .doNothing }
///     return .reduce { $0.isLoading = true }
///            .produce { ctx in
///                ctx.environment.api.submit(form).asEffect()
///            }
/// }
/// ```
///
/// ## Reading post-mutation state
///
/// From an `async` context, hop to the main actor:
///
/// ```swift
/// return .produce { ctx in
///     Effect.task {
///         let count = await ctx.stateAfter?.count  // main-actor hop happens here
///         return .log(count: count)
///     }
/// }
/// ```
///
/// From a Combine / RxSwift effect, use the `readStateAfter()` helper defined in the
/// corresponding target.
///
/// ## Functor (covariant on State, covariant on Environment)
///
/// `PostReducerContext` is a **Functor** on both `State` (via ``map(_:)`` and ``compactMap(_:)``)
/// and on `Environment` (via ``mapEnvironment(_:)``). Lifting operations use these inside
/// `contramapEnvironment` on `Reader` to project the axes the feature actually needs:
///
/// ```swift
/// // Project state axis only:
/// c.effect.contramapEnvironment { $0.map { $0.authState } }
///
/// // Project environment axis only:
/// c.effect.contramapEnvironment { $0.mapEnvironment { $0.auth } }
/// ```
public struct PostReducerContext<State: Sendable, Environment: Sendable>: Sendable {
    // MARK: - Public

    /// The store's injected environment — accessible from any context without `await`.
    public let environment: Environment

    /// The state after all mutations from this dispatch cycle have been applied.
    ///
    /// Requires `@MainActor`. From a non-`@MainActor` context, use
    /// `await MainActor.run { ctx.stateAfter }` or the `readStateAfter()` helper.
    @MainActor
    public var stateAfter: State? { _getter() }

    // MARK: - Package-internal

    /// The raw getter closure. Marked `@Sendable @MainActor` so that lifting transforms can
    /// forward it to child `PostReducerContext` instances without actor or Sendable violations.
    package let _getter: @Sendable @MainActor () -> State?

    // MARK: - Init

    package init(environment: Environment, getter: @escaping @Sendable @MainActor () -> State?) {
        self.environment = environment
        _getter = getter
    }
}

// MARK: - Functor (covariant on State)

extension PostReducerContext {
    /// Projects this context to a narrower state type using a total transformation.
    ///
    /// The resulting context wraps the same `environment` and a composed getter that applies `f`
    /// to the post-mutation state on each read.
    ///
    /// ```swift
    /// c.effect.contramapEnvironment { $0.map { $0.authState } }
    /// ```
    ///
    /// - Parameter f: A `@Sendable` transformation from `State` to `LocalState`.
    /// - Returns: A `PostReducerContext<LocalState, Environment>` with the same environment.
    public func map<LocalState: Sendable>(
        _ f: @escaping @Sendable (State) -> LocalState
    ) -> PostReducerContext<LocalState, Environment> {
        PostReducerContext<LocalState, Environment>(environment: environment, getter: { _getter().map(f) })
    }

    /// Projects this context to a narrower state type using a partial transformation.
    ///
    /// The resulting ``stateAfter`` is `nil` when the Store is deallocated **or** when `f`
    /// returns `nil`.
    ///
    /// ```swift
    /// c.effect.contramapEnvironment { $0.compactMap(AppState.prism.loggedIn.preview) }
    /// ```
    ///
    /// - Parameter f: A `@Sendable` partial transformation from `State` to `LocalState?`.
    /// - Returns: A `PostReducerContext<LocalState, Environment>` returning `nil` when either
    ///   the Store is gone or `f` returns `nil`.
    public func compactMap<LocalState: Sendable>(
        _ f: @escaping @Sendable (State) -> LocalState?
    ) -> PostReducerContext<LocalState, Environment> {
        PostReducerContext<LocalState, Environment>(environment: environment, getter: { _getter().flatMap(f) })
    }
}

// MARK: - Functor (covariant on Environment)

extension PostReducerContext {
    /// Transforms the environment inside this context using a projection function.
    ///
    /// Used by lifting operations when narrowing the environment from a global to a local type.
    /// Primarily used inside `contramapEnvironment` on `Reader` to project the environment axis:
    ///
    /// ```swift
    /// // liftEnvironment: Reader<PostReducerContext<State, LocalEnv>, _> →
    /// //                  Reader<PostReducerContext<State, GlobalEnv>, _>
    /// c.effect.contramapEnvironment { $0.mapEnvironment { $0.auth } }
    /// ```
    ///
    /// - Parameter f: A `@Sendable` transformation from `Environment` to `NewEnvironment`.
    /// - Returns: A `PostReducerContext<State, NewEnvironment>` with the same state getter.
    public func mapEnvironment<NewEnvironment: Sendable>(
        _ f: @escaping @Sendable (Environment) -> NewEnvironment
    ) -> PostReducerContext<State, NewEnvironment> {
        PostReducerContext<State, NewEnvironment>(environment: f(environment), getter: _getter)
    }
}
