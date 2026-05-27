import CoreFP
import DataStructure

// MARK: - Bridge / routing helpers with optional mutation
//
// These overloads add action-to-action routing (and optional state mutation) on top of any
// existing `Behavior` value. They mirror `Middleware+Bridge.swift` but with an extra optional
// `reduce:` parameter that lets you co-locate the state mutation with the routing.
//
// All state access is lazy. The key invariant:
//   – State is **never** accessed unless the action filter passes.
//   – If neither `reduce:` nor `when:` is provided, `mutation` is `.identity` — state is not
//     even passed by inout reference to any closure, guaranteeing zero CoW interaction.
//   – Overloads that accept `reduce:` make it a *required* parameter (no default). When you
//     want routing-only, use the overload *without* the `reduce:` label — it reaches `.identity`
//     directly rather than through a wrapped no-op closure.
//
// Four families of overloads, 28 variants total:
//
//   Prism / AffineTraversal — extract a typed payload from the action (variants 1–12):
//     .on(AppAction.prism.didLoad, dispatch: .renderItems)
//     .on(AppAction.prism.didLoad, dispatch: .renderItems, when: { !$0.isLoaded })
//     .on(AppAction.prism.didLoad, dispatch: .renderItems, reduce: { items, s in s.items = items })
//     .on(AppAction.prism.didLoad, dispatch: .renderItems,
//         reduce: { items, s in s.items = items }, when: { !$0.isLoaded })
//
//   KeyPath (macro-generated enum case properties) — variants 13–20:
//     .on(\.didLoad, dispatch: .renderItems)
//     .on(\.didLoad, dispatch: .renderItems, when: { !$0.isLoaded })
//     .on(\.didLoad, dispatch: .renderItems, reduce: { items, s in s.items = items })
//     .on(\.didLoad, dispatch: .renderItems,
//         reduce: { items, s in s.items = items }, when: { !$0.isLoaded })
//
//   Bool predicate — general action test, fixed dispatch (variants 21–26):
//     .on({ case .reset = $0 }, reduce: { $0.count = 0 })
//     .on({ case .submit = $0 }, reduce: { $0.isLoading = true }, dispatch: .doSubmit,
//         when: { !$0.isLoading })
//
//   Pure routing (no mutation, (Action) -> Action?) — variants 27–28:
//     .on { action in guard case .didSearch(let q) = action else { return nil }; return .search(q) }
//
// Every `.on(...)` call is equivalent to `.combine(self, routingBehavior)`.

extension Behavior {
    // MARK: 1. Prism + dispatch: (no reduce, no when — zero state interaction)

    /// Routes actions matched by a `Prism`, dispatching the extracted value. No state is ever
    /// accessed; `mutation` is `.identity`.
    ///
    /// ```swift
    /// .on(AppAction.prism.didLoad, dispatch: AppAction.renderItems)
    /// ```
    public func on<T: Sendable>(
        _ prism: Prism<Action, T>,
        dispatch out: @escaping @Sendable (T) -> Action
    ) -> Self {
        .combine(self, Behavior { action, _ in
            guard let value = prism.preview(action) else { return .doNothing }
            return Consequence(mutation: .identity, effect: Reader { _ in Effect.just(out(value)) })
        })
    }

    // MARK: 2. Prism + dispatch: + when: (no reduce — one state copy for predicate)

    /// Routes actions matched by a `Prism`, dispatching the extracted value, guarded by a
    /// state predicate. `mutation` is `.identity`; one state copy for the predicate check.
    ///
    /// ```swift
    /// .on(AppAction.prism.didLoad, dispatch: AppAction.renderItems, when: { !$0.isLoaded })
    /// ```
    public func on<T: Sendable>(
        _ prism: Prism<Action, T>,
        dispatch out: @escaping @Sendable (T) -> Action,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard let value = prism.preview(action) else { return .doNothing }
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            return Consequence(mutation: .identity, effect: Reader { _ in Effect.just(out(value)) })
        })
    }

    // MARK: 3. Prism + dispatch: + reduce: (no when)

    /// Routes actions matched by a `Prism`, transforming the extracted value into a dispatch,
    /// with a state mutation.
    ///
    /// ```swift
    /// .on(AppAction.prism.didLoad,
    ///     dispatch: AppAction.renderItems,
    ///     reduce: { items, state in state.items = items; state.isLoading = false })
    /// ```
    public func on<T: Sendable>(
        _ prism: Prism<Action, T>,
        dispatch out: @escaping @Sendable (T) -> Action,
        reduce: @escaping @Sendable (T, inout State) -> Void
    ) -> Self {
        .combine(self, Behavior { action, _ in
            guard let value = prism.preview(action) else { return .doNothing }
            return Consequence(
                mutation: EndoMut { state in reduce(value, &state) },
                effect: Reader { _ in Effect.just(out(value)) }
            )
        })
    }

    // MARK: 4. Prism + dispatch: + reduce: + when: (full)

    /// Routes actions matched by a `Prism`, with mutation and dispatch guarded by a predicate.
    public func on<T: Sendable>(
        _ prism: Prism<Action, T>,
        dispatch out: @escaping @Sendable (T) -> Action,
        reduce: @escaping @Sendable (T, inout State) -> Void,
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

    // MARK: 5. Prism pair (no reduce, no when — zero state interaction)

    /// Routes actions matched by `inPrism`, embedding the value through `outPrism`.
    /// No state is ever accessed; `mutation` is `.identity`.
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

    // MARK: 6. Prism pair + when: (no reduce — one state copy for predicate)

    /// Routes actions matched by `inPrism` through `outPrism`, guarded by a state predicate.
    /// `mutation` is `.identity`; one state copy for the predicate check.
    public func on<T: Sendable>(
        _ inPrism: Prism<Action, T>,
        _ outPrism: Prism<Action, T>,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(inPrism, dispatch: outPrism.review, when: condition)
    }

    // MARK: 7. Prism pair + reduce: (no when)

    /// Routes actions matched by `inPrism`, embedding the value through `outPrism`, with
    /// a state mutation.
    ///
    /// ```swift
    /// .on(AppAction.prism.searchQuery, AppAction.prism.updateSearch,
    ///     reduce: { query, state in state.lastQuery = query })
    /// ```
    public func on<T: Sendable>(
        _ inPrism: Prism<Action, T>,
        _ outPrism: Prism<Action, T>,
        reduce: @escaping @Sendable (T, inout State) -> Void
    ) -> Self {
        on(inPrism, dispatch: outPrism.review, reduce: reduce)
    }

    // MARK: 8. Prism pair + reduce: + when: (full)

    /// Routes actions matched by `inPrism` through `outPrism`, with mutation and dispatch
    /// guarded by a predicate.
    public func on<T: Sendable>(
        _ inPrism: Prism<Action, T>,
        _ outPrism: Prism<Action, T>,
        reduce: @escaping @Sendable (T, inout State) -> Void,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(inPrism, dispatch: outPrism.review, reduce: reduce, when: condition)
    }

    // MARK: 9. Void prism + dispatch: (no reduce, no when — zero state interaction)

    /// Routes a Void-payload action matched by `prism`, dispatching a fixed `out` action.
    /// No state is ever accessed; `mutation` is `.identity`.
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

    // MARK: 10. Void prism + dispatch: + when: (no reduce — one state copy for predicate)

    /// Routes a Void-payload action matched by `prism`, dispatching a fixed `out` action,
    /// guarded by a state predicate. `mutation` is `.identity`.
    public func on(
        _ prism: Prism<Action, Void>,
        dispatch out: Action,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(prism, dispatch: { _ in out }, when: condition)
    }

    // MARK: 11. Void prism + dispatch: + reduce: (no when)

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
        reduce: @escaping @Sendable (inout State) -> Void
    ) -> Self {
        on(prism, dispatch: { _ in out }, reduce: { _, s in reduce(&s) })
    }

    // MARK: 12. Void prism + dispatch: + reduce: + when: (full)

    /// Routes a Void-payload action matched by `prism`, with mutation and dispatch guarded
    /// by a predicate.
    public func on(
        _ prism: Prism<Action, Void>,
        dispatch out: Action,
        reduce: @escaping @Sendable (inout State) -> Void,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(prism, dispatch: { _ in out }, reduce: { _, s in reduce(&s) }, when: condition)
    }

    // MARK: 13. KeyPath<Action, T?> + dispatch: (no reduce, no when — zero state interaction)

    /// Routes actions using an optional key path (macro-generated enum case properties),
    /// dispatching the extracted value. No state is ever accessed; `mutation` is `.identity`.
    ///
    /// ```swift
    /// .on(\.didLoad, dispatch: AppAction.renderItems)
    /// ```
    public func on<T: Sendable>(
        _ extract: KeyPath<Action, T?>,
        dispatch out: @escaping @Sendable (T) -> Action
    ) -> Self {
        .combine(self, Behavior { action, _ in
            guard let value = action[keyPath: extract] else { return .doNothing }
            return Consequence(mutation: .identity, effect: Reader { _ in Effect.just(out(value)) })
        })
    }

    // MARK: 14. KeyPath<Action, T?> + dispatch: + when: (no reduce — one state copy for predicate)

    /// Routes actions using an optional key path, guarded by a state predicate.
    /// `mutation` is `.identity`; one state copy for the predicate check.
    ///
    /// ```swift
    /// .on(\.didTapBuy, dispatch: AppAction.checkout, when: { $0.isLoggedIn })
    /// ```
    public func on<T: Sendable>(
        _ extract: KeyPath<Action, T?>,
        dispatch out: @escaping @Sendable (T) -> Action,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard let value = action[keyPath: extract] else { return .doNothing }
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            return Consequence(mutation: .identity, effect: Reader { _ in Effect.just(out(value)) })
        })
    }

    // MARK: 15. KeyPath<Action, T?> + dispatch: + reduce: (no when)

    /// Routes actions using an optional key path, with a state mutation.
    ///
    /// ```swift
    /// .on(\.didLoad,
    ///     dispatch: AppAction.renderItems,
    ///     reduce: { items, state in state.items = items; state.isLoading = false })
    /// ```
    public func on<T: Sendable>(
        _ extract: KeyPath<Action, T?>,
        dispatch out: @escaping @Sendable (T) -> Action,
        reduce: @escaping @Sendable (T, inout State) -> Void
    ) -> Self {
        .combine(self, Behavior { action, _ in
            guard let value = action[keyPath: extract] else { return .doNothing }
            return Consequence(
                mutation: EndoMut { state in reduce(value, &state) },
                effect: Reader { _ in Effect.just(out(value)) }
            )
        })
    }

    // MARK: 16. KeyPath<Action, T?> + dispatch: + reduce: + when: (full)

    /// Routes actions using a key path, with mutation and dispatch guarded by a predicate.
    public func on<T: Sendable>(
        _ extract: KeyPath<Action, T?>,
        dispatch out: @escaping @Sendable (T) -> Action,
        reduce: @escaping @Sendable (T, inout State) -> Void,
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

    // MARK: 17. KeyPath<Action, Void?> + dispatch: (no reduce, no when — zero state interaction)

    /// Routes a Void-payload key path action, dispatching a fixed `out` action.
    /// No state is ever accessed; `mutation` is `.identity`.
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

    // MARK: 18. KeyPath<Action, Void?> + dispatch: + when: (no reduce — one state copy for predicate)

    /// Routes a Void-payload key path action, dispatching a fixed action, guarded by a predicate.
    /// `mutation` is `.identity`; one state copy for the predicate check.
    public func on(
        _ extract: KeyPath<Action, Void?>,
        dispatch out: Action,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(extract, dispatch: { _ in out }, when: condition)
    }

    // MARK: 19. KeyPath<Action, Void?> + dispatch: + reduce: (no when)

    /// Routes a Void-payload key path action, dispatching a fixed `out` action, with state mutation.
    ///
    /// ```swift
    /// .on(\.didTapLogout,
    ///     dispatch: AppAction.auth(.logout),
    ///     reduce: { state in state.isLoggingOut = true })
    /// ```
    public func on(
        _ extract: KeyPath<Action, Void?>,
        dispatch out: Action,
        reduce: @escaping @Sendable (inout State) -> Void
    ) -> Self {
        on(extract, dispatch: { _ in out }, reduce: { _, s in reduce(&s) })
    }

    // MARK: 20. KeyPath<Action, Void?> + dispatch: + reduce: + when: (full)

    /// Routes a Void-payload key path action, dispatching a fixed action, with mutation and
    /// dispatch guarded by a predicate.
    public func on(
        _ extract: KeyPath<Action, Void?>,
        dispatch out: Action,
        reduce: @escaping @Sendable (inout State) -> Void,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(extract, dispatch: { _ in out }, reduce: { _, s in reduce(&s) }, when: condition)
    }

    // MARK: 21–26. Bool predicate variants (lazy state access)
    //
    // Unlike the Prism/KeyPath variants above, these separate the action filter from state
    // access so the compiler (and the implementation) can guarantee:
    //   – no state copy if the predicate returns false
    //   – no state copy at all when `reduce:` and `when:` are both absent (variants 21, 27–28)
    //
    // Dispatch is always a fixed `Action`; for cases where dispatch depends on state after
    // mutation, use `.produce { ctx in }` directly on the returned `Consequence`.

    // MARK: 21. Bool predicate — pure routing, no state

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

    // MARK: 22. Bool predicate + when: — dispatch guarded by pre-mutation state

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

    // MARK: 23. Bool predicate + reduce: — mutation only, no dispatch

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

    // MARK: 24. Bool predicate + reduce: + dispatch:

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

    // MARK: 25. Bool predicate + reduce: + when: — mutation guarded by pre-mutation state

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

    // MARK: 26. Bool predicate + reduce: + dispatch: + when: — full

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

    // MARK: 27. Closure (Action) -> Action? (no mutation — pure routing)

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

    // MARK: 28. Closure (Action) -> Action? + when: (no mutation — pure routing)

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
