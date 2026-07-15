// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

// MARK: - Per-axis transforms

extension Middleware {
    /// Lifts the action axis of this middleware using a `Prism`, embedding it in a wider global
    /// action type.
    ///
    /// Only global actions for which `prism.preview` returns a non-nil local action will reach
    /// this middleware. Actions produced by the middleware's effects are wrapped via `prism.review`
    /// before re-entering the ``Store``.
    ///
    /// ```swift
    /// let lifted = authMiddleware.liftAction(AppAction.prism.auth)
    /// // lifted: Middleware<AppAction, AuthState, AuthEnvironment>
    /// ```
    ///
    /// - Parameter prism: A `Prism<GlobalAction, Action>` where `preview` extracts the local
    ///   action and `review` embeds a local action into the global type.
    /// - Returns: A `Middleware<GlobalAction, State, Environment>` that ignores unmatched
    ///   global actions and re-wraps outgoing actions through `prism.review`.
    public func liftAction<GlobalAction: Sendable>(
        _ prism: Prism<GlobalAction, Action>
    ) -> Middleware<GlobalAction, State, Environment> {
        Middleware<GlobalAction, State, Environment>(
            handle: { action, context in
                guard let local = prism.preview(action) else { return Reader { _ in .empty } }
                return self.handle(local, context).map { $0.map(prism.review) }
            },
            supervisor: supervisor.map { inner in
                { @MainActor @Sendable (state: State) in inner(state).map { $0.map { $0.mapAction(prism.review) } } }
            }
        )
    }

    /// Lifts the state axis of this middleware using a projection closure, embedding it in a
    /// wider global state type.
    ///
    /// The `PreReducerContext<GlobalState>` is projected to `PreReducerContext<State>` using
    /// `f` via ``PreReducerContext/map(_:)``. The same projection is applied in
    /// ``PostReducerContext`` (via `contramapEnvironment` on the returned `Reader`) so the
    /// middleware sees the correct post-mutation state in phase 3. Because ``Middleware`` is
    /// read-only on state, only the `get` direction is needed.
    ///
    /// ```swift
    /// let lifted = authMiddleware.liftState { $0.authState }
    /// // lifted: Middleware<AuthAction, AppState, AuthEnvironment>
    /// ```
    ///
    /// - Parameter f: A function from `GlobalState` to the local `State`.
    /// - Returns: A `Middleware<Action, GlobalState, Environment>` that projects the state
    ///   before passing it to this middleware.
    public func liftState<GlobalState: Sendable>(
        _ f: @escaping @Sendable (GlobalState) -> State
    ) -> Middleware<Action, GlobalState, Environment> {
        Middleware<Action, GlobalState, Environment>(
            handle: { action, context in self.handle(action, context.map(f)).contramapEnvironment { $0.map(f) } },
            supervisor: supervisor.map { inner in { @MainActor @Sendable (state: GlobalState) in inner(f(state)) } }
        )
    }

    /// Lifts the state axis of this middleware using a `Lens`. Only the `get` half is used —
    /// middleware is read-only on state.
    ///
    /// ```swift
    /// let lifted = authMiddleware.liftState(AppState.lens.auth)
    /// ```
    ///
    /// - Parameter lens: A `Lens<GlobalState, State>` from which only `get` is used.
    /// - Returns: A `Middleware<Action, GlobalState, Environment>` focused on the sub-state.
    public func liftState<GlobalState: Sendable>(
        _ lens: Lens<GlobalState, State>
    ) -> Middleware<Action, GlobalState, Environment> {
        liftState(lens.get)
    }

    /// Lifts the state axis of this middleware using a `Prism`, focusing on one enum case
    /// of the global state.
    ///
    /// The middleware sees `nil` state both when the ``Store`` has been deallocated and when
    /// the focused enum case is not the currently active case.
    ///
    /// ```swift
    /// // Middleware runs only while AppState is in the .loggedIn(_) case
    /// let lifted = sessionMiddleware.liftState(AppState.prism.loggedIn)
    /// ```
    ///
    /// - Parameter prism: A `Prism<GlobalState, State>` focusing on one case of an enum state.
    /// - Returns: A `Middleware<Action, GlobalState, Environment>` that sees `nil` when the
    ///   prism's focused case is absent.
    public func liftState<GlobalState: Sendable>(
        _ prism: Prism<GlobalState, State>
    ) -> Middleware<Action, GlobalState, Environment> {
        Middleware<Action, GlobalState, Environment>(
            handle: { action, context in
                self.handle(action, context.compactMap(prism.preview)).contramapEnvironment { $0.compactMap(prism.preview) }
            },
            supervisor: supervisor.map { inner in
                { @MainActor @Sendable (state: GlobalState) in prism.preview(state).map { inner($0) } ?? Reader { _ in [] } }
            }
        )
    }

    /// Lifts the state axis of this middleware using an `AffineTraversal`, focusing on a
    /// partially-present sub-state.
    ///
    /// The middleware sees `nil` state both when the ``Store`` is deallocated and when the
    /// traversal's focus is absent (e.g., an optional property is `nil`).
    ///
    /// ```swift
    /// // Middleware runs only while AppState.currentUser is non-nil
    /// let lifted = userMiddleware.liftState(AppState.traversal.optionalUser)
    /// ```
    ///
    /// - Parameter traversal: An `AffineTraversal<GlobalState, State>` that may not have a focus.
    /// - Returns: A `Middleware<Action, GlobalState, Environment>` that sees `nil` when the
    ///   traversal's focus is absent.
    public func liftState<GlobalState: Sendable>(
        _ traversal: AffineTraversal<GlobalState, State>
    ) -> Middleware<Action, GlobalState, Environment> {
        Middleware<Action, GlobalState, Environment>(
            handle: { action, context in
                self.handle(action, context.compactMap(traversal.preview)).contramapEnvironment { $0.compactMap(traversal.preview) }
            },
            supervisor: supervisor.map { inner in
                { @MainActor @Sendable (state: GlobalState) in traversal.preview(state).map { inner($0) } ?? Reader { _ in [] } }
            }
        )
    }

    /// Lifts this middleware over an **optional** sub-state — the 0-or-1 sibling of
    /// ``liftCollection``/``liftEach`` (0-or-n).
    ///
    /// The middleware is skipped entirely while the optional is `nil`, and runs focused on the
    /// unwrapped value while it is `.some` — the shape presentation uses for a child shown only
    /// while its state exists.
    ///
    /// ```swift
    /// let lifted = dayMiddleware.liftOptional(\AppState.currentDay)   // currentDay: DayDetail.State?
    /// ```
    ///
    /// - Parameter optional: A `WritableKeyPath<GlobalState, State?>` to the optional sub-state.
    /// - Returns: A `Middleware<Action, GlobalState, Environment>` skipped entirely while absent.
    public func liftOptional<GlobalState: Sendable>(
        _ optional: WritableKeyPath<GlobalState, State?>
    ) -> Middleware<Action, GlobalState, Environment> {
        let traversal = affineTraversal(optional)
        return Middleware<Action, GlobalState, Environment>(
            // While the sub-state is `nil` the inner middleware is skipped — no effect is produced.
            handle: { action, context in
                guard context.stateBefore?[keyPath: optional] != nil else { return Reader { _ in .empty } }
                return self.handle(action, context.compactMap(traversal.preview))
                    .contramapEnvironment { $0.compactMap(traversal.preview) }
            },
            supervisor: supervisor.map { inner in
                { @MainActor @Sendable (state: GlobalState) in traversal.preview(state).map { inner($0) } ?? Reader { _ in [] } }
            }
        )
    }

    /// Lifts the environment axis of this middleware using a projection closure, embedding it
    /// in a wider global environment.
    ///
    /// The closure extracts the local `Environment` from a `GlobalEnvironment`. Feature
    /// middlewares can declare narrow environment dependencies while the app composes them
    /// against the full `AppEnvironment`:
    ///
    /// ```swift
    /// let lifted = authMiddleware.liftEnvironment { $0.auth }
    /// // lifted: Middleware<AuthAction, AuthState, AppEnvironment>
    /// ```
    ///
    /// - Parameter f: A function from `GlobalEnvironment` to the local `Environment`.
    /// - Returns: A `Middleware<Action, State, GlobalEnvironment>` that projects the environment
    ///   before injecting it into this middleware's effects.
    public func liftEnvironment<GlobalEnvironment: Sendable>(
        _ f: @escaping @Sendable (GlobalEnvironment) -> Environment
    ) -> Middleware<Action, State, GlobalEnvironment> {
        Middleware<Action, State, GlobalEnvironment>(
            handle: { action, context in self.handle(action, context).contramapEnvironment { $0.mapEnvironment(f) } },
            supervisor: supervisor.map { inner in { @MainActor @Sendable (state: State) in inner(state).contramapEnvironment(f) } }
        )
    }
}
