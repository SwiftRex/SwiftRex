// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

// MARK: - Bridge / routing helpers

//
// These overloads add action-to-action routing on top of any existing `Middleware` value.
// Start from `Middleware.identity` and chain `.on(...)` calls to build pure routing pipelines
// without opening a `Reader` or touching the environment.
//
// All state access is lazy: state is never copied unless the action filter passes first.
//
// Three families of overloads, 12 variants total:
//
//   Prism / AffineTraversal — extract a typed payload from the action (variants 1–6):
//     .on(AppAction.prism.didSearch, dispatch: AppAction.performSearch)
//     .on(AppAction.prism.didTapBuy, dispatch: AppAction.checkout, when: { $0.isLoggedIn })
//
//   KeyPath (macro-generated enum case properties) — variants 7–10:
//     .on(\.didSearch, dispatch: AppAction.performSearch)
//     .on(\.didTapLogout, dispatch: AppAction.auth(.logout))
//
//   Bool predicate — general action test, fixed dispatch (variants 11–12):
//   Use these when the test inspects the action's payload; for a plain case match prefer the
//   KeyPath form above (`\.case`). A closure cannot hold a bare `case` pattern (patterns are not
//   values in Swift), so a payload test reads as an `if case` expression:
//     .on({ if case .setVolume(let v) = $0, v == 0 { true } else { false } }, dispatch: .showMutedBanner)
//     .on({ if case .seek(let t) = $0, t < 0 { true } else { false } }, dispatch: .clampToStart)
//
// Every `.on(...)` call is equivalent to `.combine(self, routingMiddleware)` where
// `routingMiddleware` handles the matched action and dispatches the result.

extension Middleware {
    // MARK: 1. Prism + dispatch:

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

    // MARK: 2. Prism + dispatch: + when:

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
            guard let value = prism.preview(action) else { return Reader { _ in .empty } }
            let stateBefore = context.stateBefore
            return Reader { _ in
                guard let state = stateBefore, condition(state) else { return .empty }
                return Effect.just(out(value))
            }
        })
    }

    // MARK: 3. Prism pair (no dispatch: label)

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

    // MARK: 4. Prism pair + when:

    /// Routes actions matched by `inPrism` through `outPrism`, guarded by a state predicate.
    public func on<T: Sendable>(
        _ inPrism: Prism<Action, T>,
        _ outPrism: Prism<Action, T>,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(inPrism, dispatch: outPrism.review, when: condition)
    }

    // MARK: 5. Void prism + dispatch: Action value

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

    // MARK: 6. Void prism + dispatch: + when:

    /// Routes a Void-payload action matched by `prism`, dispatching a fixed `out` action,
    /// guarded by a state predicate.
    public func on(
        _ prism: Prism<Action, Void>,
        dispatch out: Action,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(prism, dispatch: { _ in out }, when: condition)
    }

    // MARK: 7. KeyPath<Action, T?> + dispatch:

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

    // MARK: 8. KeyPath<Action, T?> + dispatch: + when:

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
            guard let value = action[keyPath: extract] else { return Reader { _ in .empty } }
            let stateBefore = context.stateBefore
            return Reader { _ in
                guard let state = stateBefore, condition(state) else { return .empty }
                return Effect.just(out(value))
            }
        })
    }

    // MARK: 9. KeyPath<Action, Void?> + dispatch: Action value

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

    // MARK: 10. KeyPath<Action, Void?> + dispatch: + when:

    /// Routes a Void-payload key path action, dispatching a fixed `out` action,
    /// guarded by a state predicate.
    public func on(
        _ extract: KeyPath<Action, Void?>,
        dispatch out: Action,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        on(extract, dispatch: { _ in out }, when: condition)
    }

    // MARK: 11–12. Bool predicate variants (lazy state access)

    //
    // These complement the unlabeled closure variants above with a Bool predicate
    // and fixed dispatch, guaranteeing:
    //   - no state copy if the predicate returns `false`
    //   - no state copy at all when `when:` is absent

    // MARK: 11. Bool predicate + dispatch: (no state)

    /// Routes actions that satisfy `predicate`, dispatching `out`. No state is ever read.
    ///
    /// Use a Bool predicate when the test inspects the action's payload; for a plain case match
    /// prefer the KeyPath form `.on(\.case, dispatch:)`.
    ///
    /// ```swift
    /// .on({ if case .setVolume(let v) = $0, v == 0 { true } else { false } }, dispatch: AppAction.showMutedBanner)
    /// ```
    public func on(
        _ predicate: @escaping @Sendable (Action) -> Bool,
        dispatch out: Action
    ) -> Self {
        .combine(self, Middleware { action, _ in
            guard predicate(action) else { return Reader { _ in .empty } }
            return Reader { _ in Effect.just(out) }
        })
    }

    // MARK: 12. Bool predicate + dispatch: + when: (state read after action match)

    /// Routes actions that satisfy `predicate`, dispatching `out` only when `condition` holds.
    /// State is read only after `predicate` returns `true`.
    ///
    /// ```swift
    /// .on({ if case .seek(let t) = $0, t < 0 { true } else { false } },
    ///     dispatch: .clampToStart,
    ///     when: { $0.isPlaying })
    /// ```
    public func on(
        _ predicate: @escaping @Sendable (Action) -> Bool,
        dispatch out: Action,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Middleware { action, context in
            guard predicate(action) else { return Reader { _ in .empty } }
            let stateBefore = context.stateBefore
            return Reader { _ in
                guard let state = stateBefore, condition(state) else { return .empty }
                return Effect.just(out)
            }
        })
    }
}
