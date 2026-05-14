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
        Middleware<GlobalAction, State, Environment> { action, state in
            guard let local = action.compactMap(prism.preview) else {
                return Reader { _ in .empty }
            }
            return self.handle(local, state).map { $0.map(prism.review) }
        }
    }

    /// Lifts the state axis of this middleware using a projection closure, embedding it in a
    /// wider global state type.
    ///
    /// `StateAccess<GlobalState>` is mapped to `StateAccess<State>` using `f`, giving this
    /// middleware a narrowly-typed view of state. Because ``Middleware`` is read-only on state,
    /// only the `get` direction of the mapping is needed.
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
        _ f: @escaping @Sendable @MainActor (GlobalState) -> State
    ) -> Middleware<Action, GlobalState, Environment> {
        Middleware<Action, GlobalState, Environment> { action, globalAccess in
            self.handle(action, globalAccess.map(f))
        }
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
    /// the focused enum case is not the currently active case. In both situations,
    /// ``StateAccess/snapshotState()`` returns `nil`, and well-written middlewares skip
    /// producing effects in that case.
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
        Middleware<Action, GlobalState, Environment> { action, globalAccess in
            self.handle(action, globalAccess.flatMap(prism.preview))
        }
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
        Middleware<Action, GlobalState, Environment> { action, globalAccess in
            self.handle(action, globalAccess.flatMap(traversal.preview))
        }
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
        Middleware<Action, State, GlobalEnvironment> { action, state in
            self.handle(action, state).contramapEnvironment(f)
        }
    }
}

// MARK: - Combined lift

extension Middleware {
    /// Lifts all three axes simultaneously using a `Prism` for action, a closure for state,
    /// and a closure for environment.
    ///
    /// Equivalent to chaining ``liftAction(_:)``, ``liftState(_:)-9kjxz``, and
    /// ``liftEnvironment(_:)`` in sequence. The state projection uses a plain function, which
    /// is the most flexible form:
    ///
    /// ```swift
    /// let lifted = authMiddleware.lift(
    ///     action:      AppAction.prism.auth,
    ///     state:       { $0.authState },
    ///     environment: { $0.auth }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A `Prism<GlobalAction, Action>` for the action axis.
    ///   - f: A closure from `GlobalState` to the local `State`.
    ///   - g: A closure from `GlobalEnvironment` to the local `Environment`.
    /// - Returns: A fully-lifted `Middleware<GlobalAction, GlobalState, GlobalEnvironment>`.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state f: @escaping @Sendable @MainActor (GS) -> State,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Middleware<GA, GS, GE> {
        liftAction(prism).liftState(f).liftEnvironment(g)
    }

    /// Lifts all three axes simultaneously using a `Prism` for action, a `Lens` for state,
    /// and a closure for environment.
    ///
    /// ```swift
    /// let lifted = authMiddleware.lift(
    ///     action:      AppAction.prism.auth,
    ///     state:       AppState.lens.auth,
    ///     environment: { $0.auth }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A `Prism<GlobalAction, Action>` for the action axis.
    ///   - lens: A `Lens<GlobalState, State>` for the state axis.
    ///   - g: A closure from `GlobalEnvironment` to the local `Environment`.
    /// - Returns: A fully-lifted `Middleware<GlobalAction, GlobalState, GlobalEnvironment>`.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state lens: Lens<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Middleware<GA, GS, GE> {
        liftAction(prism).liftState(lens).liftEnvironment(g)
    }

    /// Lifts all three axes simultaneously using a `Prism` for action, a `Prism` for state,
    /// and a closure for environment.
    ///
    /// The middleware is completely skipped when the state prism's focused enum case is not active.
    ///
    /// ```swift
    /// let lifted = sessionMiddleware.lift(
    ///     action:      AppAction.prism.session,
    ///     state:       AppState.prism.loggedIn,
    ///     environment: { $0.session }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A `Prism<GlobalAction, Action>` for the action axis.
    ///   - statePrism: A `Prism<GlobalState, State>` for the state axis.
    ///   - g: A closure from `GlobalEnvironment` to the local `Environment`.
    /// - Returns: A fully-lifted `Middleware<GlobalAction, GlobalState, GlobalEnvironment>` that
    ///   is a no-op when the state prism's focused case is absent.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state statePrism: Prism<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Middleware<GA, GS, GE> {
        liftAction(prism).liftState(statePrism).liftEnvironment(g)
    }

    /// Lifts all three axes simultaneously using a `Prism` for action, an `AffineTraversal`
    /// for state, and a closure for environment.
    ///
    /// The middleware is completely skipped when the traversal's focus is absent.
    ///
    /// ```swift
    /// let lifted = detailMiddleware.lift(
    ///     action:      AppAction.prism.detail,
    ///     state:       AppState.traversal.selectedItem,
    ///     environment: { $0.detail }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A `Prism<GlobalAction, Action>` for the action axis.
    ///   - traversal: An `AffineTraversal<GlobalState, State>` for the state axis.
    ///   - g: A closure from `GlobalEnvironment` to the local `Environment`.
    /// - Returns: A fully-lifted `Middleware<GlobalAction, GlobalState, GlobalEnvironment>` that
    ///   is a no-op when the traversal's focus is absent.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state traversal: AffineTraversal<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Middleware<GA, GS, GE> {
        liftAction(prism).liftState(traversal).liftEnvironment(g)
    }
}
