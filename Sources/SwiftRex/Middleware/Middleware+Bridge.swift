import CoreFP
import DataStructure

// MARK: - Bridge / routing helpers
//
// These overloads add action-to-action routing on top of any existing `Middleware` value.
// Start from `Middleware.identity` and chain `.on(...)` calls to build pure routing pipelines
// without opening a `Reader` or touching the environment:
//
//   let bridge = Middleware<AppAction, AppState, World>.identity
//       .on(\.didSearch, dispatch: AppAction.performSearch)
//       .on(AppAction.prism.didTapLogout, dispatch: AppAction.auth(.logout))
//
// Every `on(...)` call is equivalent to `.combine(self, routingMiddleware)` where
// `routingMiddleware` handles the matched action and dispatches the result.

extension Middleware {

    // MARK: 1. Closure (Action) -> Action?

    /// Routes actions using a free closure: on match, dispatches the returned action.
    ///
    /// ```swift
    /// .on { action in
    ///     guard case .didSearch(let q) = action else { return nil }
    ///     return .performSearch(q)
    /// }
    /// ```
    public func on(
        _ fn: @escaping @Sendable (Action) -> Action?
    ) -> Self {
        .combine(self, Middleware { action, _ in
            Reader { _ in fn(action).map { Effect.just($0) } ?? .empty }
        })
    }

    // MARK: 2. Closure (Action) -> Action? + when:

    /// Routes actions using a free closure, guarded by a state predicate.
    ///
    /// The dispatch only occurs when both `fn` returns non-nil **and** `condition` returns `true`
    /// for the current pre-mutation state.
    ///
    /// ```swift
    /// .on({ action in guard case .retry = action else { return nil }; return .reload },
    ///     when: { $0.retryCount < 3 })
    /// ```
    public func on(
        _ fn: @escaping @Sendable (Action) -> Action?,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Middleware { action, context in
            // Capture state on @MainActor before entering the @Sendable Reader
            let stateBefore = context.stateBefore
            return Reader { _ in
                guard let out = fn(action) else { return .empty }
                guard let state = stateBefore, condition(state) else { return .empty }
                return Effect.just(out)
            }
        })
    }

    // MARK: 3. Prism + dispatch:

    /// Routes actions matched by a `Prism`, transforming the extracted value into a dispatch.
    ///
    /// ```swift
    /// .on(AppAction.prism.didSearch, dispatch: AppAction.performSearch)
    /// ```
    public func on<T: Sendable>(
        _ prism: Prism<Action, T>,
        dispatch out: @escaping @Sendable (T) -> Action
    ) -> Self {
        .combine(self, Middleware { action, _ in
            Reader { _ in prism.preview(action).map { Effect.just(out($0)) } ?? .empty }
        })
    }

    // MARK: 4. Prism + dispatch: + when:

    /// Routes actions matched by a `Prism`, guarded by a state predicate.
    ///
    /// ```swift
    /// .on(AppAction.prism.didTapBuy, dispatch: AppAction.checkout, when: { $0.isLoggedIn })
    /// ```
    public func on<T: Sendable>(
        _ prism: Prism<Action, T>,
        dispatch out: @escaping @Sendable (T) -> Action,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Middleware { action, context in
            let stateBefore = context.stateBefore
            return Reader { _ in
                guard let value = prism.preview(action) else { return .empty }
                guard let state = stateBefore, condition(state) else { return .empty }
                return Effect.just(out(value))
            }
        })
    }

    // MARK: 5. Prism pair (no dispatch: label)

    /// Routes actions matched by `inPrism`, embedding the extracted value back through `outPrism`.
    ///
    /// Both prisms share the same payload type `T`:
    ///
    /// ```swift
    /// .on(AppAction.prism.searchQuery, AppAction.prism.updateSearch)
    /// ```
    public func on<T: Sendable>(
        _ inPrism: Prism<Action, T>,
        _ outPrism: Prism<Action, T>
    ) -> Self {
        on(inPrism, dispatch: outPrism.review)
    }

    // MARK: 6. Prism pair + when:

    /// Routes actions matched by `inPrism` through `outPrism`, guarded by a state predicate.
    public func on<T: Sendable>(
        _ inPrism: Prism<Action, T>,
        _ outPrism: Prism<Action, T>,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(inPrism, dispatch: outPrism.review, when: condition)
    }

    // MARK: 7. Void prism + dispatch: Action value

    /// Routes a Void-payload action matched by `prism`, dispatching a fixed `out` action.
    ///
    /// ```swift
    /// .on(AppAction.prism.didTapLogout, dispatch: AppAction.auth(.logout))
    /// ```
    public func on(
        _ prism: Prism<Action, Void>,
        dispatch out: Action
    ) -> Self {
        on(prism, dispatch: { _ in out })
    }

    // MARK: 8. Void prism + dispatch: + when:

    /// Routes a Void-payload action matched by `prism`, dispatching a fixed `out` action,
    /// guarded by a state predicate.
    public func on(
        _ prism: Prism<Action, Void>,
        dispatch out: Action,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(prism, dispatch: { _ in out }, when: condition)
    }

    // MARK: 9. KeyPath<Action, T?> + dispatch:

    /// Routes actions using an optional key path (macro-generated enum case properties),
    /// transforming the extracted value into a dispatch.
    ///
    /// ```swift
    /// .on(\.didSearch, dispatch: AppAction.performSearch)
    /// ```
    public func on<T: Sendable>(
        _ extract: KeyPath<Action, T?>,
        dispatch out: @escaping @Sendable (T) -> Action
    ) -> Self {
        .combine(self, Middleware { action, _ in
            Reader { _ in action[keyPath: extract].map { Effect.just(out($0)) } ?? .empty }
        })
    }

    // MARK: 10. KeyPath<Action, T?> + dispatch: + when:

    /// Routes actions using an optional key path, guarded by a state predicate.
    ///
    /// ```swift
    /// .on(\.didTapBuy, dispatch: AppAction.checkout, when: { $0.isLoggedIn })
    /// ```
    public func on<T: Sendable>(
        _ extract: KeyPath<Action, T?>,
        dispatch out: @escaping @Sendable (T) -> Action,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Middleware { action, context in
            let stateBefore = context.stateBefore
            return Reader { _ in
                guard let value = action[keyPath: extract] else { return .empty }
                guard let state = stateBefore, condition(state) else { return .empty }
                return Effect.just(out(value))
            }
        })
    }

    // MARK: 11. KeyPath<Action, Void?> + dispatch: Action value

    /// Routes a Void-payload key path action, dispatching a fixed `out` action.
    ///
    /// ```swift
    /// .on(\.didTapLogout, dispatch: AppAction.auth(.logout))
    /// ```
    public func on(
        _ extract: KeyPath<Action, Void?>,
        dispatch out: Action
    ) -> Self {
        on(extract, dispatch: { _ in out })
    }

    // MARK: 12. KeyPath<Action, Void?> + dispatch: + when:

    /// Routes a Void-payload key path action, dispatching a fixed `out` action,
    /// guarded by a state predicate.
    public func on(
        _ extract: KeyPath<Action, Void?>,
        dispatch out: Action,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(extract, dispatch: { _ in out }, when: condition)
    }
}
