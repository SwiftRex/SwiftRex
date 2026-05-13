import CoreFP
import DataStructure

// MARK: - Action axis

extension Behavior {
    /// Lifts the action axis using a `Prism`. Only global actions matched by the prism reach
    /// this behavior; produced actions are wrapped via `review` before re-entering the Store.
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
    /// Projects the state axis using a `WritableKeyPath`. The `EndoMut` is lifted through the
    /// keypath; `StateAccess` is mapped to the sub-state.
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

    /// Projects the state axis using a `Lens`. Uses `get` for `StateAccess` mapping and
    /// `lift` for zero-copy `EndoMut` composition.
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

    /// Projects the state axis using a `Prism`. The `EndoMut` is a no-op when the focused
    /// case is absent; `StateAccess` returns `nil` in that case too.
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

    /// Projects the state axis using an `AffineTraversal`. The `EndoMut` is a no-op and
    /// `StateAccess` returns `nil` when the traversal's focus is absent.
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
    /// Narrows the environment using a projection closure.
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

// MARK: - Combined lift

extension Behavior {
    /// Lifts all three axes simultaneously using a `WritableKeyPath` for state.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state keyPath: WritableKeyPath<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Behavior<GA, GS, GE> {
        liftAction(prism).liftState(keyPath).liftEnvironment(g)
    }

    /// Lifts all three axes using a `Lens` for state.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state stateLens: Lens<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Behavior<GA, GS, GE> {
        liftAction(prism).liftState(stateLens).liftEnvironment(g)
    }

    /// Lifts all three axes using a `Prism` for state — behavior is skipped when
    /// the focused enum case is not active.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state statePrism: Prism<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Behavior<GA, GS, GE> {
        liftAction(prism).liftState(statePrism).liftEnvironment(g)
    }

    /// Lifts all three axes using an `AffineTraversal` for state — behavior is skipped
    /// when the traversal's focus is absent.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action prism: Prism<GA, Action>,
        state traversal: AffineTraversal<GS, State>,
        environment g: @escaping @Sendable (GE) -> Environment
    ) -> Behavior<GA, GS, GE> {
        liftAction(prism).liftState(traversal).liftEnvironment(g)
    }
}
