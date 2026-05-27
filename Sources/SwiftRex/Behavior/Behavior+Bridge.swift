import CoreFP
import DataStructure

// MARK: - Bridge / routing helpers with optional mutation
//
// These overloads add action-to-action routing (and optional state mutation) on top of any
// existing `Behavior` value. They mirror `Middleware+Bridge.swift` but with an extra optional
// `reduce:` parameter that lets you co-locate the state mutation with the routing:
//
//   let behavior = Behavior<AppAction, AppState, World>.identity
//       .on(\.didLoad, dispatch: AppAction.renderItems, reduce: { items, state in
//           state.items = items
//       })
//
// Every `on(...)` call is equivalent to `.combine(self, routingBehavior)`.

extension Behavior {
    // MARK: 1. Closure (Action, inout State) -> Action?

    /// Routes actions using a closure that mutates state and optionally dispatches an action.
    ///
    /// The closure receives the action and an `inout` copy of the current state. Returning a
    /// non-nil action from the closure causes that action to be dispatched after the mutation.
    ///
    /// ```swift
    /// .on { action, state in
    ///     guard case .increment = action else { return nil }
    ///     state.count += 1
    ///     return state.count > 10 ? .showWarning : nil
    /// }
    /// ```
    ///
    /// The closure is called **twice** (on a throwaway copy of state to capture the return value,
    /// then on the real `inout State` for the actual mutation) — it must be a pure function of
    /// `(Action, inout State)` with no observable side effects beyond the state changes.
    public func on(
        _ fn: @escaping @Sendable (Action, inout State) -> Action?
    ) -> Self {
        .combine(self, Behavior { action, context in
            // Call on a throwaway copy first to capture the return value (@MainActor OK here)
            let dispatched: Action? = {
                guard var state = context.stateBefore else { return nil }
                return fn(action, &state)
            }()
            return Consequence(
                mutation: EndoMut { state in _ = fn(action, &state) },
                effect: Reader { _ in dispatched.map { Effect.just($0) } ?? .empty }
            )
        })
    }

    // MARK: 2. Closure (Action, inout State) -> Action? + when:

    /// Routes actions using a closure that mutates state, guarded by a state predicate.
    ///
    /// The mutation and optional dispatch only occur when `condition` returns `true` for the
    /// current pre-mutation state.
    public func on(
        _ fn: @escaping @Sendable (Action, inout State) -> Action?,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            let dispatched: Action? = {
                var copy = state
                return fn(action, &copy)
            }()
            return Consequence(
                mutation: EndoMut { s in _ = fn(action, &s) },
                effect: Reader { _ in dispatched.map { Effect.just($0) } ?? .empty }
            )
        })
    }

    // MARK: 3. Prism + dispatch: + reduce:

    /// Routes actions matched by a `Prism`, transforming the extracted value into a dispatch,
    /// with an optional state mutation.
    ///
    /// ```swift
    /// .on(AppAction.prism.didLoad,
    ///     dispatch: AppAction.renderItems,
    ///     reduce: { items, state in state.items = items; state.isLoading = false })
    /// ```
    public func on<T: Sendable>(
        _ prism: Prism<Action, T>,
        dispatch out: @escaping @Sendable (T) -> Action,
        reduce: @escaping @Sendable (T, inout State) -> Void = { _, _ in }
    ) -> Self {
        .combine(self, Behavior { action, _ in
            guard let value = prism.preview(action) else { return .doNothing }
            return Consequence(
                mutation: EndoMut { state in reduce(value, &state) },
                effect: Reader { _ in Effect.just(out(value)) }
            )
        })
    }

    // MARK: 4. Prism + dispatch: + reduce: + when:

    /// Routes actions matched by a `Prism`, with mutation and dispatch guarded by a predicate.
    public func on<T: Sendable>(
        _ prism: Prism<Action, T>,
        dispatch out: @escaping @Sendable (T) -> Action,
        reduce: @escaping @Sendable (T, inout State) -> Void = { _, _ in },
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard let value = prism.preview(action) else { return .doNothing }
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            return Consequence(
                mutation: EndoMut { s in reduce(value, &s) },
                effect: Reader { _ in Effect.just(out(value)) }
            )
        })
    }

    // MARK: 5. Prism pair (no dispatch: label) + reduce:

    /// Routes actions matched by `inPrism`, embedding the value through `outPrism`, with
    /// optional state mutation.
    ///
    /// ```swift
    /// .on(AppAction.prism.searchQuery, AppAction.prism.updateSearch,
    ///     reduce: { query, state in state.lastQuery = query })
    /// ```
    public func on<T: Sendable>(
        _ inPrism: Prism<Action, T>,
        _ outPrism: Prism<Action, T>,
        reduce: @escaping @Sendable (T, inout State) -> Void = { _, _ in }
    ) -> Self {
        on(inPrism, dispatch: outPrism.review, reduce: reduce)
    }

    // MARK: 6. Prism pair + reduce: + when:

    /// Routes actions matched by `inPrism` through `outPrism`, with mutation and dispatch
    /// guarded by a predicate.
    public func on<T: Sendable>(
        _ inPrism: Prism<Action, T>,
        _ outPrism: Prism<Action, T>,
        reduce: @escaping @Sendable (T, inout State) -> Void = { _, _ in },
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(inPrism, dispatch: outPrism.review, reduce: reduce, when: condition)
    }

    // MARK: 7. Void prism + dispatch: Action value + reduce:

    /// Routes a Void-payload action matched by `prism`, dispatching a fixed `out` action,
    /// with optional state mutation.
    ///
    /// ```swift
    /// .on(AppAction.prism.didTapLogout,
    ///     dispatch: AppAction.auth(.logout),
    ///     reduce: { state in state.isLoggingOut = true })
    /// ```
    public func on(
        _ prism: Prism<Action, Void>,
        dispatch out: Action,
        reduce: @escaping @Sendable (inout State) -> Void = { _ in }
    ) -> Self {
        on(prism, dispatch: { _ in out }, reduce: { _, s in reduce(&s) })
    }

    // MARK: 8. Void prism + dispatch: + reduce: + when:

    /// Routes a Void-payload action matched by `prism`, with mutation and dispatch guarded
    /// by a predicate.
    public func on(
        _ prism: Prism<Action, Void>,
        dispatch out: Action,
        reduce: @escaping @Sendable (inout State) -> Void = { _ in },
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(prism, dispatch: { _ in out }, reduce: { _, s in reduce(&s) }, when: condition)
    }

    // MARK: 9. KeyPath<Action, T?> + dispatch: + reduce:

    /// Routes actions using an optional key path (macro-generated enum case properties),
    /// with optional state mutation.
    ///
    /// ```swift
    /// .on(\.didLoad,
    ///     dispatch: AppAction.renderItems,
    ///     reduce: { items, state in state.items = items; state.isLoading = false })
    /// ```
    public func on<T: Sendable>(
        _ extract: KeyPath<Action, T?>,
        dispatch out: @escaping @Sendable (T) -> Action,
        reduce: @escaping @Sendable (T, inout State) -> Void = { _, _ in }
    ) -> Self {
        .combine(self, Behavior { action, _ in
            guard let value = action[keyPath: extract] else { return .doNothing }
            return Consequence(
                mutation: EndoMut { state in reduce(value, &state) },
                effect: Reader { _ in Effect.just(out(value)) }
            )
        })
    }

    // MARK: 10. KeyPath<Action, T?> + dispatch: + reduce: + when:

    /// Routes actions using a key path, with mutation and dispatch guarded by a predicate.
    ///
    /// ```swift
    /// .on(\.didTapBuy, dispatch: AppAction.checkout, when: { $0.isLoggedIn })
    /// ```
    public func on<T: Sendable>(
        _ extract: KeyPath<Action, T?>,
        dispatch out: @escaping @Sendable (T) -> Action,
        reduce: @escaping @Sendable (T, inout State) -> Void = { _, _ in },
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard let value = action[keyPath: extract] else { return .doNothing }
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            return Consequence(
                mutation: EndoMut { s in reduce(value, &s) },
                effect: Reader { _ in Effect.just(out(value)) }
            )
        })
    }

    // MARK: 11. KeyPath<Action, Void?> + dispatch: Action value + reduce:

    /// Routes a Void-payload key path action, dispatching a fixed `out` action, with optional
    /// state mutation.
    ///
    /// ```swift
    /// .on(\.didTapLogout,
    ///     dispatch: AppAction.auth(.logout),
    ///     reduce: { state in state.isLoggingOut = true })
    /// ```
    public func on(
        _ extract: KeyPath<Action, Void?>,
        dispatch out: Action,
        reduce: @escaping @Sendable (inout State) -> Void = { _ in }
    ) -> Self {
        on(extract, dispatch: { _ in out }, reduce: { _, s in reduce(&s) })
    }

    // MARK: 12. KeyPath<Action, Void?> + dispatch: + reduce: + when:

    /// Routes a Void-payload key path action, dispatching a fixed action, with mutation and
    /// dispatch guarded by a predicate.
    public func on(
        _ extract: KeyPath<Action, Void?>,
        dispatch out: Action,
        reduce: @escaping @Sendable (inout State) -> Void = { _ in },
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(extract, dispatch: { _ in out }, reduce: { _, s in reduce(&s) }, when: condition)
    }

    // MARK: 13. Closure (Action) -> Action? (no mutation — pure routing)

    /// Routes actions using a free closure with no state mutation.
    ///
    /// Identical to the `Middleware` overload but available on `Behavior` for symmetry when
    /// building pure action-routing pipelines:
    ///
    /// ```swift
    /// behaviorSoFar.on { action in
    ///     guard case .didSearch(let q) = action else { return nil }
    ///     return .performSearch(q)
    /// }
    /// ```
    public func on(
        _ fn: @escaping @Sendable (Action) -> Action?
    ) -> Self {
        .combine(self, Behavior { action, _ in
            Consequence(
                mutation: .identity,
                effect: Reader { _ in fn(action).map { Effect.just($0) } ?? .empty }
            )
        })
    }

    // MARK: 14. Closure (Action) -> Action? + when: (no mutation — pure routing)

    /// Routes actions using a free closure with no state mutation, guarded by a predicate.
    public func on(
        _ fn: @escaping @Sendable (Action) -> Action?,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            return Consequence(
                mutation: .identity,
                effect: Reader { _ in fn(action).map { Effect.just($0) } ?? .empty }
            )
        })
    }
}
