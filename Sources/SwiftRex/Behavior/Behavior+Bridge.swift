import CoreFP
import DataStructure

// MARK: - Bridge / routing helpers with optional mutation
//
// These overloads add action-to-action routing (and optional state mutation) on top of any
// existing `Behavior` value. They mirror `Middleware+Bridge.swift` but with an extra optional
// `reduce:` parameter that lets you co-locate the state mutation with the routing.
//
// All state access is lazy: state is never copied unless the action filter passes first.
//
// Three families of overloads, 18 variants total:
//
//   Prism / AffineTraversal — extract a typed payload from the action (variants 1–6):
//     .on(AppAction.prism.didLoad, dispatch: .renderItems, reduce: { items, s in s.items = items })
//
//   KeyPath (macro-generated enum case properties) — variants 7–10:
//     .on(\.didLoad, dispatch: .renderItems, reduce: { items, s in s.items = items })
//
//   Bool predicate — general action test, fixed dispatch (variants 11–16):
//     .on({ case .reset = $0 }, reduce: { $0.count = 0 })
//     .on({ case .submit = $0 }, reduce: { $0.isLoading = true }, dispatch: .doSubmit, when: { !$0.isLoading })
//
//   Pure routing (no mutation, (Action) -> Action?) — variants 17–18:
//     .on { action in guard case .didSearch(let q) = action else { return nil }; return .search(q) }
//
// Every `.on(...)` call is equivalent to `.combine(self, routingBehavior)`.

extension Behavior {
    // MARK: 1. Prism + dispatch: + reduce:

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

    // MARK: 2. Prism + dispatch: + reduce: + when:

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

    // MARK: 3. Prism pair (no dispatch: label) + reduce:

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

    // MARK: 4. Prism pair + reduce: + when:

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

    // MARK: 5. Void prism + dispatch: Action value + reduce:

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

    // MARK: 6. Void prism + dispatch: + reduce: + when:

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

    // MARK: 7. KeyPath<Action, T?> + dispatch: + reduce:

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

    // MARK: 8. KeyPath<Action, T?> + dispatch: + reduce: + when:

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

    // MARK: 9. KeyPath<Action, Void?> + dispatch: Action value + reduce:

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

    // MARK: 10. KeyPath<Action, Void?> + dispatch: + reduce: + when:

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

    // MARK: 11–18. Bool predicate variants (lazy state access)
    //
    // Unlike the blob-closure variants above, these separate the action filter from state
    // access so the compiler (and the implementation) can guarantee:
    //   - no state copy if the predicate returns false
    //   - no state copy if neither `reduce:` nor `when:` is provided
    //
    // Dispatch is always a fixed `Action`; for cases where dispatch depends on state after
    // mutation, use `.produce { ctx in }` directly on the returned `Consequence`.

    // MARK: 11. Bool predicate — pure routing, no state

    /// Routes actions that satisfy `predicate`, dispatching `out`. No state is ever read.
    ///
    /// ```swift
    /// .on({ case .didLogOut = $0 }, dispatch: .auth(.logOut))
    /// ```
    public func on(
        _ predicate: @escaping @Sendable (Action) -> Bool,
        dispatch out: Action
    ) -> Self {
        .combine(self, Behavior { action, _ in
            guard predicate(action) else { return .doNothing }
            return Consequence(mutation: .identity, effect: Reader { _ in Effect.just(out) })
        })
    }

    // MARK: 12. Bool predicate + when: — dispatch guarded by pre-mutation state

    /// Routes actions that satisfy `predicate`, dispatching `out` only when `condition` holds.
    /// State is read only after `predicate` returns `true`.
    ///
    /// ```swift
    /// .on({ case .retry = $0 }, dispatch: .reload, when: { $0.retryCount < 3 })
    /// ```
    public func on(
        _ predicate: @escaping @Sendable (Action) -> Bool,
        dispatch out: Action,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard predicate(action) else { return .doNothing }
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            return Consequence(mutation: .identity, effect: Reader { _ in Effect.just(out) })
        })
    }

    // MARK: 13. Bool predicate + reduce: — mutation only, no dispatch

    /// Applies `reduce` when `predicate` returns `true`. No action is dispatched.
    /// No state copy occurs if `predicate` returns `false`.
    ///
    /// ```swift
    /// .on({ case .toggle = $0 }, reduce: { $0.isActive.toggle() })
    /// ```
    public func on(
        _ predicate: @escaping @Sendable (Action) -> Bool,
        reduce: @escaping @Sendable (inout State) -> Void
    ) -> Self {
        .combine(self, Behavior { action, _ in
            guard predicate(action) else { return .doNothing }
            return Consequence(mutation: EndoMut(reduce), effect: Reader { _ in .empty })
        })
    }

    // MARK: 14. Bool predicate + reduce: + dispatch:

    /// Applies `reduce` and dispatches `out` when `predicate` returns `true`.
    /// No state copy occurs if `predicate` returns `false`.
    ///
    /// ```swift
    /// .on({ case .didLoad = $0 },
    ///     reduce: { $0.isLoading = false },
    ///     dispatch: .renderItems)
    /// ```
    public func on(
        _ predicate: @escaping @Sendable (Action) -> Bool,
        reduce: @escaping @Sendable (inout State) -> Void,
        dispatch out: Action
    ) -> Self {
        .combine(self, Behavior { action, _ in
            guard predicate(action) else { return .doNothing }
            return Consequence(mutation: EndoMut(reduce), effect: Reader { _ in Effect.just(out) })
        })
    }

    // MARK: 15. Bool predicate + reduce: + when: — mutation guarded by pre-mutation state

    /// Applies `reduce` when `predicate` returns `true` AND `condition` holds.
    /// State is read only after `predicate` returns `true`. No action is dispatched.
    ///
    /// ```swift
    /// .on({ case .submit = $0 },
    ///     reduce: { $0.isSubmitting = true },
    ///     when: { !$0.isSubmitting })
    /// ```
    public func on(
        _ predicate: @escaping @Sendable (Action) -> Bool,
        reduce: @escaping @Sendable (inout State) -> Void,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard predicate(action) else { return .doNothing }
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            return Consequence(mutation: EndoMut(reduce), effect: Reader { _ in .empty })
        })
    }

    // MARK: 16. Bool predicate + reduce: + dispatch: + when: — full

    /// Applies `reduce` and dispatches `out` when `predicate` returns `true` AND `condition` holds.
    /// State is read only after `predicate` returns `true`.
    ///
    /// ```swift
    /// .on({ case .submit = $0 },
    ///     reduce: { $0.isSubmitting = true },
    ///     dispatch: .submitForm,
    ///     when: { !$0.isSubmitting })
    /// ```
    public func on(
        _ predicate: @escaping @Sendable (Action) -> Bool,
        reduce: @escaping @Sendable (inout State) -> Void,
        dispatch out: Action,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard predicate(action) else { return .doNothing }
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            return Consequence(mutation: EndoMut(reduce), effect: Reader { _ in Effect.just(out) })
        })
    }

    // MARK: 17. Closure (Action) -> Action? (no mutation — pure routing)

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

    // MARK: 18. Closure (Action) -> Action? + when: (no mutation — pure routing)

    /// Routes actions using a free closure with no state mutation, guarded by a predicate.
    public func on(
        _ fn: @escaping @Sendable (Action) -> Action?,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard let out = fn(action) else { return .doNothing }
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            return Consequence(
                mutation: .identity,
                effect: Reader { _ in Effect.just(out) }
            )
        })
    }
}
