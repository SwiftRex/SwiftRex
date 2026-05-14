import CoreFP
import DataStructure

// MARK: - Lift (closure-based)

extension Reducer {
    /// Lifts using a getter for action and getter+setter for state.
    public func lift<GlobalAction, GlobalState: Sendable>(
        actionGetter: @escaping @Sendable (GlobalAction) -> ActionType?,
        stateGetter: @escaping @Sendable (GlobalState) -> StateType,
        stateSetter: @escaping @Sendable (inout GlobalState, StateType) -> Void
    ) -> Reducer<GlobalAction, GlobalState> {
        .reduce { globalAction in
            guard let localAction = actionGetter(globalAction) else { return .identity }
            return Lens(get: stateGetter, setMut: stateSetter).lift(self.reduce(localAction))
        }
    }

    /// Lifts action axis only using a getter closure. State type is unchanged.
    public func lift<GlobalAction>(
        actionGetter: @escaping @Sendable (GlobalAction) -> ActionType?
    ) -> Reducer<GlobalAction, StateType> {
        .reduce { globalAction in
            guard let localAction = actionGetter(globalAction) else { return .identity }
            return self.reduce(localAction)
        }
    }

    /// Lifts state axis only using getter and setter closures. Action type is unchanged.
    public func lift<GlobalState: Sendable>(
        stateGetter: @escaping @Sendable (GlobalState) -> StateType,
        stateSetter: @escaping @Sendable (inout GlobalState, StateType) -> Void
    ) -> Reducer<ActionType, GlobalState> {
        .reduce { action in Lens(get: stateGetter, setMut: stateSetter).lift(self.reduce(action)) }
    }
}

// MARK: - Lift (WritableKeyPath — state only)

extension Reducer {
    /// Lifts state axis only using a `WritableKeyPath`. Action type is unchanged.
    public func lift<GlobalState>(
        state: WritableKeyPath<GlobalState, StateType>
    ) -> Reducer<ActionType, GlobalState> {
        .reduce { action in EndoMut { globalState in self.reduce(action)(&globalState[keyPath: state]) } }
    }
}

// MARK: - Lift (optics — action: Prism)

extension Reducer {
    /// Lifts action axis only using a `Prism`. State type is unchanged.
    public func lift<GlobalAction>(
        action prism: Prism<GlobalAction, ActionType>
    ) -> Reducer<GlobalAction, StateType> {
        .reduce { globalAction in
            guard let localAction = prism.preview(globalAction) else { return .identity }
            return self.reduce(localAction)
        }
    }

    /// Lifts both axes using a `Prism` for action and a `WritableKeyPath` for state.
    public func lift<GlobalAction, GlobalState: Sendable>(
        action prism: Prism<GlobalAction, ActionType>,
        state keyPath: WritableKeyPath<GlobalState, StateType>
    ) -> Reducer<GlobalAction, GlobalState> {
        .reduce { globalAction in
            guard let localAction = prism.preview(globalAction) else { return .identity }
            return EndoMut { globalState in self.reduce(localAction)(&globalState[keyPath: keyPath]) }
        }
    }

    /// Lifts both axes using a `Prism` for action and a `Lens` for state.
    public func lift<GlobalAction, GlobalState>(
        action prism: Prism<GlobalAction, ActionType>,
        state lens: Lens<GlobalState, StateType>
    ) -> Reducer<GlobalAction, GlobalState> {
        .reduce { globalAction in
            guard let localAction = prism.preview(globalAction) else { return .identity }
            return lens.lift(self.reduce(localAction))
        }
    }

    /// Lifts both axes using a `Prism` for action and a `Prism` for state.
    public func lift<GlobalAction, GlobalState>(
        action actionPrism: Prism<GlobalAction, ActionType>,
        state statePrism: Prism<GlobalState, StateType>
    ) -> Reducer<GlobalAction, GlobalState> {
        .reduce { globalAction in
            guard let localAction = actionPrism.preview(globalAction) else { return .identity }
            return statePrism.lift(self.reduce(localAction))
        }
    }

    /// Lifts both axes using a `Prism` for action and an `AffineTraversal` for state.
    public func lift<GlobalAction, GlobalState>(
        action prism: Prism<GlobalAction, ActionType>,
        state traversal: AffineTraversal<GlobalState, StateType>
    ) -> Reducer<GlobalAction, GlobalState> {
        .reduce { globalAction in
            guard let localAction = prism.preview(globalAction) else { return .identity }
            return traversal.lift(self.reduce(localAction))
        }
    }
}

// MARK: - Lift (optics — action: AffineTraversal)
//
// `AffineTraversal` for action is valid because Reducer's action axis is input-only
// (consumed, never produced). Only `preview` is used — `set` is not called.

extension Reducer {
    /// Lifts action axis only using an `AffineTraversal`. State type is unchanged.
    public func lift<GlobalAction>(
        action traversal: AffineTraversal<GlobalAction, ActionType>
    ) -> Reducer<GlobalAction, StateType> {
        .reduce { globalAction in
            guard let localAction = traversal.preview(globalAction) else { return .identity }
            return self.reduce(localAction)
        }
    }

    /// Lifts both axes using an `AffineTraversal` for action and a `WritableKeyPath` for state.
    public func lift<GlobalAction, GlobalState: Sendable>(
        action traversal: AffineTraversal<GlobalAction, ActionType>,
        state keyPath: WritableKeyPath<GlobalState, StateType>
    ) -> Reducer<GlobalAction, GlobalState> {
        .reduce { globalAction in
            guard let localAction = traversal.preview(globalAction) else { return .identity }
            return EndoMut { globalState in self.reduce(localAction)(&globalState[keyPath: keyPath]) }
        }
    }

    /// Lifts both axes using an `AffineTraversal` for action and a `Lens` for state.
    public func lift<GlobalAction, GlobalState>(
        action traversal: AffineTraversal<GlobalAction, ActionType>,
        state lens: Lens<GlobalState, StateType>
    ) -> Reducer<GlobalAction, GlobalState> {
        .reduce { globalAction in
            guard let localAction = traversal.preview(globalAction) else { return .identity }
            return lens.lift(self.reduce(localAction))
        }
    }

    /// Lifts both axes using an `AffineTraversal` for action and a `Prism` for state.
    public func lift<GlobalAction, GlobalState>(
        action traversal: AffineTraversal<GlobalAction, ActionType>,
        state prism: Prism<GlobalState, StateType>
    ) -> Reducer<GlobalAction, GlobalState> {
        .reduce { globalAction in
            guard let localAction = traversal.preview(globalAction) else { return .identity }
            return prism.lift(self.reduce(localAction))
        }
    }

    /// Lifts both axes using an `AffineTraversal` for each.
    public func lift<GlobalAction, GlobalState>(
        action actionTraversal: AffineTraversal<GlobalAction, ActionType>,
        state stateTraversal: AffineTraversal<GlobalState, StateType>
    ) -> Reducer<GlobalAction, GlobalState> {
        .reduce { globalAction in
            guard let localAction = actionTraversal.preview(globalAction) else { return .identity }
            return stateTraversal.lift(self.reduce(localAction))
        }
    }
}

// MARK: - Lift (optics — state only)

extension Reducer {
    /// Lifts state axis only using a `Lens`. Action type is unchanged.
    public func lift<GlobalState>(
        state lens: Lens<GlobalState, StateType>
    ) -> Reducer<ActionType, GlobalState> {
        .reduce { action in lens.lift(self.reduce(action)) }
    }

    /// Lifts state axis only using a `Prism` — the reducer is a no-op when the focused
    /// case is absent.
    public func lift<GlobalState>(
        state prism: Prism<GlobalState, StateType>
    ) -> Reducer<ActionType, GlobalState> {
        .reduce { action in prism.lift(self.reduce(action)) }
    }

    /// Lifts state axis only using an `AffineTraversal` — the reducer is a no-op when
    /// the focus is absent.
    public func lift<GlobalState>(
        state traversal: AffineTraversal<GlobalState, StateType>
    ) -> Reducer<ActionType, GlobalState> {
        .reduce { action in traversal.lift(self.reduce(action)) }
    }
}
