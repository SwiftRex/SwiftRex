import CoreFP
import DataStructure

// MARK: - Action axis

extension Behavior {
    /// Lifts the action axis of this behavior using a `Prism`, embedding it in a wider global
    /// action type.
    ///
    /// Only global actions for which `prism.preview` returns a non-nil local action will reach
    /// this behavior. Actions produced by the behavior's effects are wrapped via `prism.review`
    /// before re-entering the ``Store``.
    ///
    /// This is the standard way to wire a feature behavior into the app-level behavior:
    ///
    /// ```swift
    /// // authBehavior handles AuthAction, sees AuthState, uses AuthEnvironment
    /// // After lift it handles AppAction, sees AuthState, uses AuthEnvironment
    /// let lifted = authBehavior.liftAction(AppAction.prism.auth)
    /// ```
    ///
    /// - Parameter prism: A `Prism<GlobalAction, Action>` where `preview` extracts the local
    ///   action from a global action and `review` embeds a local action into the global type.
    /// - Returns: A `Behavior<GlobalAction, State, Environment>` that ignores global actions not
    ///   matched by the prism and re-wraps outgoing actions through the prism's `review`.
    public func liftAction<GlobalAction: Sendable>(
        _ prism: Prism<GlobalAction, Action>
    ) -> Behavior<GlobalAction, State, Environment> {
        Behavior<GlobalAction, State, Environment> { action, stateAccess in
            guard let local = action.compactMap(prism.preview) else { return .doNothing }
            let c = self.handle(local, stateAccess)
            return Consequence(
                mutation: c.mutation,
                effect: Reader { env in c.effect.runReader(env).map(prism.review) }
            )
        }
    }
}

// MARK: - State axis

extension Behavior {
    /// Lifts the state axis of this behavior using a `WritableKeyPath`, embedding it in a wider
    /// global state type.
    ///
    /// The key path is used in two ways:
    /// - To project `StateAccess<GlobalState>` to `StateAccess<State>` (pre- and post-mutation reads).
    /// - To lift the returned `EndoMut<State>` through the key path so it mutates the correct
    ///   property inside `GlobalState`.
    ///
    /// ```swift
    /// // counterBehavior sees CounterState; after lift it sees AppState.counterState
    /// let lifted = counterBehavior.liftState(\AppState.counterState)
    /// ```
    ///
    /// - Parameter keyPath: A `WritableKeyPath<GlobalState, State>` identifying the sub-state
    ///   property within the global state.
    /// - Returns: A `Behavior<Action, GlobalState, Environment>` that reads and writes only
    ///   the sub-state identified by `keyPath`.
    public func liftState<GlobalState: Sendable>(
        _ keyPath: WritableKeyPath<GlobalState, State>
    ) -> Behavior<Action, GlobalState, Environment> {
        Behavior<Action, GlobalState, Environment> { action, globalAccess in
            let c = self.handle(action, globalAccess.map { $0[keyPath: keyPath] })
            return Consequence(
                mutation: lens(keyPath).lift(c.mutation),
                effect: c.effect
            )
        }
    }

    /// Lifts the state axis of this behavior using a `Lens`, embedding it in a wider global
    /// state type.
    ///
    /// The lens `get` is used to map `StateAccess<GlobalState>` to `StateAccess<State>`;
    /// the lens `lift` is used to promote `EndoMut<State>` to `EndoMut<GlobalState>`.
    ///
    /// ```swift
    /// let lifted = authBehavior.liftState(AppState.lens.auth)
    /// ```
    ///
    /// - Parameter stateLens: A `Lens<GlobalState, State>` describing how to read and write
    ///   the sub-state within the global state.
    /// - Returns: A `Behavior<Action, GlobalState, Environment>` focused on the sub-state.
    public func liftState<GlobalState: Sendable>(
        _ stateLens: Lens<GlobalState, State>
    ) -> Behavior<Action, GlobalState, Environment> {
        Behavior<Action, GlobalState, Environment> { action, globalAccess in
            let c = self.handle(action, globalAccess.map(stateLens.get))
            return Consequence(
                mutation: stateLens.lift(c.mutation),
                effect: c.effect
            )
        }
    }

    /// Lifts the state axis of this behavior using a `Prism`, embedding it in an enum-shaped
    /// global state.
    ///
    /// When the focused enum case is absent, both the mutation and the `StateAccess` return
    /// "absent" — the mutation becomes a no-op and ``StateAccess/snapshotState()`` returns `nil`.
    /// This means the behavior is completely skipped when the relevant state case is not active.
    ///
    /// ```swift
    /// // The behavior only runs while AppState is in the .authenticated(_) case
    /// let lifted = authBehavior.liftState(AppState.prism.authenticated)
    /// ```
    ///
    /// - Parameter statePrism: A `Prism<GlobalState, State>` focusing on one case of an enum state.
    /// - Returns: A `Behavior<Action, GlobalState, Environment>` that is a no-op when the
    ///   prism's focused case is absent from the global state.
    public func liftState<GlobalState: Sendable>(
        _ statePrism: Prism<GlobalState, State>
    ) -> Behavior<Action, GlobalState, Environment> {
        Behavior<Action, GlobalState, Environment> { action, globalAccess in
            let c = self.handle(action, globalAccess.flatMap(statePrism.preview))
            return Consequence(
                mutation: statePrism.lift(c.mutation),
                effect: c.effect
            )
        }
    }

    /// Lifts the state axis of this behavior using an `AffineTraversal`, embedding it in a
    /// partially-focused global state.
    ///
    /// When the traversal's focus is absent (e.g., an optional property is `nil` or the
    /// targeted enum case is not active), both the mutation and the `StateAccess` are treated
    /// as absent — the mutation becomes a no-op and ``StateAccess/snapshotState()`` returns `nil`.
    ///
    /// ```swift
    /// // Run only when AppState.user is non-nil
    /// let lifted = userBehavior.liftState(AppState.traversal.optionalUser)
    /// ```
    ///
    /// - Parameter traversal: An `AffineTraversal<GlobalState, State>` that may or may not
    ///   have a focus in the current global state.
    /// - Returns: A `Behavior<Action, GlobalState, Environment>` that is a no-op when the
    ///   traversal's focus is absent.
    public func liftState<GlobalState: Sendable>(
        _ traversal: AffineTraversal<GlobalState, State>
    ) -> Behavior<Action, GlobalState, Environment> {
        Behavior<Action, GlobalState, Environment> { action, globalAccess in
            let c = self.handle(action, globalAccess.flatMap(traversal.preview))
            return Consequence(
                mutation: traversal.lift(c.mutation),
                effect: c.effect
            )
        }
    }
}

// MARK: - Environment axis

extension Behavior {
    /// Lifts the environment axis of this behavior using a projection closure, embedding it
    /// in a wider global environment.
    ///
    /// The closure extracts the local `Environment` from a `GlobalEnvironment`. The behavior's
    /// effects receive only the slice they need, keeping feature behaviors decoupled from the
    /// full app environment:
    ///
    /// ```swift
    /// // authBehavior uses AuthEnvironment; after lift it uses AppEnvironment
    /// let lifted = authBehavior.liftEnvironment { $0.auth }
    /// ```
    ///
    /// - Parameter f: A function from `GlobalEnvironment` to the local `Environment`.
    /// - Returns: A `Behavior<Action, State, GlobalEnvironment>` that projects the environment
    ///   before passing it to this behavior's effects.
    public func liftEnvironment<GlobalEnvironment: Sendable>(
        _ f: @escaping @Sendable (GlobalEnvironment) -> Environment
    ) -> Behavior<Action, State, GlobalEnvironment> {
        Behavior<Action, State, GlobalEnvironment> { action, stateAccess in
            let c = self.handle(action, stateAccess)
            return Consequence(
                mutation: c.mutation,
                effect: c.effect.contramapEnvironment(f)
            )
        }
    }
}

// MARK: - Void Environment convenience

extension Behavior where Environment == Void {
    /// Widens the environment axis from `Void` to any `GlobalEnvironment`, discarding the
    /// global environment entirely.
    ///
    /// Use this when a feature has no live dependencies (`Environment == Void`) and is being
    /// lifted into a parent store that does:
    ///
    /// ```swift
    /// counterBehavior
    ///     .liftAction(AppAction.prism.counter)
    ///     .liftState(AppState.lens.counter)
    ///     .liftEnvironment()   // discards AppEnvironment; counter needs none
    /// ```
    public func liftEnvironment<GlobalEnvironment: Sendable>() -> Behavior<Action, State, GlobalEnvironment> {
        liftEnvironment(ignore)
    }
}

// MARK: - Combined lift

extension Behavior {
    /// Lifts all three axes simultaneously using a `Prism` for action, a `WritableKeyPath`
    /// for state, and a closure for environment.
    ///
    /// Equivalent to chaining ``liftAction(_:)``, ``liftState(_:)-7bmm8``, and
    /// ``liftEnvironment(_:)`` in sequence. Use this when all three axes need widening in a
    /// single step:
    ///
    /// ```swift
    /// let appBehavior = authBehavior.lift(
    ///     action:      AppAction.prism.auth,
    ///     state:       \AppState.authState,
    ///     environment: { $0.auth }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A `Prism<GlobalAction, Action>` for the action axis.
    ///   - keyPath: A `WritableKeyPath<GlobalState, State>` for the state axis.
    ///   - g: A closure projecting `GlobalEnvironment` to the local `Environment`.
    /// - Returns: A fully-lifted `Behavior<GlobalAction, GlobalState, GlobalEnvironment>`.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state keyPath: WritableKeyPath<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Behavior<GA, GS, GE> {
        liftAction(prism).liftState(keyPath).liftEnvironment(g)
    }

    /// Lifts all three axes simultaneously using a `Prism` for action, a `Lens` for state,
    /// and a closure for environment.
    ///
    /// ```swift
    /// let appBehavior = profileBehavior.lift(
    ///     action:      AppAction.prism.profile,
    ///     state:       AppState.lens.profile,
    ///     environment: { $0.profile }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A `Prism<GlobalAction, Action>` for the action axis.
    ///   - stateLens: A `Lens<GlobalState, State>` for the state axis.
    ///   - g: A closure projecting `GlobalEnvironment` to the local `Environment`.
    /// - Returns: A fully-lifted `Behavior<GlobalAction, GlobalState, GlobalEnvironment>`.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state stateLens: Lens<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Behavior<GA, GS, GE> {
        liftAction(prism).liftState(stateLens).liftEnvironment(g)
    }

    /// Lifts all three axes simultaneously using a `Prism` for action, a `Prism` for state,
    /// and a closure for environment.
    ///
    /// The behavior is completely skipped when the state prism's focused enum case is not active.
    ///
    /// ```swift
    /// let appBehavior = loggedInBehavior.lift(
    ///     action:      AppAction.prism.loggedIn,
    ///     state:       AppState.prism.loggedIn,
    ///     environment: { $0.session }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A `Prism<GlobalAction, Action>` for the action axis.
    ///   - statePrism: A `Prism<GlobalState, State>` for the state axis.
    ///   - g: A closure projecting `GlobalEnvironment` to the local `Environment`.
    /// - Returns: A fully-lifted `Behavior<GlobalAction, GlobalState, GlobalEnvironment>` that
    ///   is a no-op when the state prism's focused case is absent.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state statePrism: Prism<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Behavior<GA, GS, GE> {
        liftAction(prism).liftState(statePrism).liftEnvironment(g)
    }

    /// Lifts all three axes simultaneously using a `Prism` for action, an `AffineTraversal`
    /// for state, and a closure for environment.
    ///
    /// The behavior is completely skipped when the traversal's focus is absent.
    ///
    /// ```swift
    /// let appBehavior = detailBehavior.lift(
    ///     action:      AppAction.prism.detail,
    ///     state:       AppState.traversal.selectedItem,
    ///     environment: { $0.detail }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A `Prism<GlobalAction, Action>` for the action axis.
    ///   - traversal: An `AffineTraversal<GlobalState, State>` for the state axis.
    ///   - g: A closure projecting `GlobalEnvironment` to the local `Environment`.
    /// - Returns: A fully-lifted `Behavior<GlobalAction, GlobalState, GlobalEnvironment>` that
    ///   is a no-op when the traversal's focus is absent.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state traversal: AffineTraversal<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Behavior<GA, GS, GE> {
        liftAction(prism).liftState(traversal).liftEnvironment(g)
    }
}
