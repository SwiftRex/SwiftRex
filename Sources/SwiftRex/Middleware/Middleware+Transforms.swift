import CoreFP
import DataStructure

// MARK: - Per-axis transforms

extension Middleware {
    /// Lifts the action axis using a `Prism`. Only global actions matched by the prism's
    /// `preview` reach this middleware; produced actions are wrapped via `review`.
    ///
    /// ```swift
    /// authMiddleware.liftAction(AppAction.prism.auth)
    /// ```
    public func liftAction<GlobalAction: Sendable>(
        _ prism: Prism<GlobalAction, Action>
    ) -> Middleware<GlobalAction, State, Environment> {
        Middleware<GlobalAction, State, Environment> { action, state in
            guard let local = action.compactMap(prism.preview) else {
                return Reader { _ in .empty }
            }
            return self.handle(local, state).map { $0.map(prism.review) }
        }
    }

    /// Projects the state axis so this middleware works on a sub-state.
    ///
    /// ```swift
    /// authMiddleware.liftState(\.authState)
    /// ```
    public func liftState<GlobalState: Sendable>(
        _ f: @escaping @Sendable @MainActor (GlobalState) -> State
    ) -> Middleware<Action, GlobalState, Environment> {
        Middleware<Action, GlobalState, Environment> { action, globalAccess in
            self.handle(action, globalAccess.map(f))
        }
    }

    /// Projects the state axis using a `Lens`. Only the `get` half is used — Middleware
    /// is read-only on state.
    public func liftState<GlobalState: Sendable>(
        _ lens: Lens<GlobalState, State>
    ) -> Middleware<Action, GlobalState, Environment> {
        liftState(lens.get)
    }

    /// Projects the state axis through a `Prism`. The middleware sees `nil` state both when
    /// the Store is deallocated and when the focused enum case is not active, so it skips
    /// producing effects in either situation.
    public func liftState<GlobalState: Sendable>(
        _ prism: Prism<GlobalState, State>
    ) -> Middleware<Action, GlobalState, Environment> {
        Middleware<Action, GlobalState, Environment> { action, globalAccess in
            self.handle(action, globalAccess.flatMap(prism.preview))
        }
    }

    /// Projects the state axis through an `AffineTraversal`. The middleware sees `nil` state
    /// both when the Store is deallocated and when the traversal's focus is absent.
    public func liftState<GlobalState: Sendable>(
        _ traversal: AffineTraversal<GlobalState, State>
    ) -> Middleware<Action, GlobalState, Environment> {
        Middleware<Action, GlobalState, Environment> { action, globalAccess in
            self.handle(action, globalAccess.flatMap(traversal.preview))
        }
    }

    /// Narrows the environment using a projection function.
    ///
    /// ```swift
    /// authMiddleware.liftEnvironment(\.auth)
    /// ```
    public func liftEnvironment<GlobalEnvironment: Sendable>(
        _ f: @escaping @Sendable (GlobalEnvironment) -> Environment
    ) -> Middleware<Action, State, GlobalEnvironment> {
        Middleware<Action, State, GlobalEnvironment> { action, state in
            self.handle(action, state).contramapEnvironment(f)
        }
    }
}

// MARK: - Combined lift

extension Middleware {
    /// Lifts all three axes simultaneously.
    ///
    /// ```swift
    /// authMiddleware.lift(
    ///     action:      AppAction.prism.auth,
    ///     state:       \.authState,
    ///     environment: \.auth
    /// )
    /// ```
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state f: @escaping @Sendable @MainActor (GS) -> State,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Middleware<GA, GS, GE> {
        liftAction(prism).liftState(f).liftEnvironment(g)
    }

    /// Lifts all three axes using a `Lens` for state.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state lens: Lens<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Middleware<GA, GS, GE> {
        liftAction(prism).liftState(lens).liftEnvironment(g)
    }

    /// Lifts all three axes using a `Prism` for state — the middleware is skipped when the
    /// focused enum case is not active.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state statePrism: Prism<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Middleware<GA, GS, GE> {
        liftAction(prism).liftState(statePrism).liftEnvironment(g)
    }

    /// Lifts all three axes using an `AffineTraversal` for state.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state traversal: AffineTraversal<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Middleware<GA, GS, GE> {
        liftAction(prism).liftState(traversal).liftEnvironment(g)
    }
}
