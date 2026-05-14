import CoreFP
import DataStructure

// MARK: - Lift (closure-based)

extension Reducer {
    /// Lifts both axes using explicit getter and setter closures.
    ///
    /// This is the lowest-level, most flexible lift overload. Use it when the action extraction
    /// or state projection cannot be expressed as a standard optic:
    ///
    /// ```swift
    /// let lifted = counterReducer.lift(
    ///     actionGetter: { if case .counter(let a) = $0 { return a } else { return nil } },
    ///     stateGetter:  { $0.counter },
    ///     stateSetter:  { $0.counter = $1 }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - actionGetter: Extracts an optional local `ActionType` from the global action.
    ///     Returns `nil` for global actions this reducer should ignore.
    ///   - stateGetter: Reads the local `StateType` from the global state.
    ///   - stateSetter: Writes the local `StateType` back into the global state (via `inout`).
    /// - Returns: A `Reducer<GlobalAction, GlobalState>` that delegates to this reducer when
    ///   `actionGetter` returns a non-nil value.
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

    /// Lifts the action axis only using a getter closure. The state type is unchanged.
    ///
    /// Use when you want to filter global actions down to a local type without changing
    /// the state type:
    ///
    /// ```swift
    /// let lifted = counterReducer.lift(
    ///     actionGetter: { if case .counter(let a) = $0 { return a } else { return nil } }
    /// )
    /// ```
    ///
    /// - Parameter actionGetter: Extracts an optional local `ActionType` from the global action.
    /// - Returns: A `Reducer<GlobalAction, StateType>` that is a no-op for unmatched global actions.
    public func lift<GlobalAction>(
        actionGetter: @escaping @Sendable (GlobalAction) -> ActionType?
    ) -> Reducer<GlobalAction, StateType> {
        .reduce { globalAction in
            guard let localAction = actionGetter(globalAction) else { return .identity }
            return self.reduce(localAction)
        }
    }

    /// Lifts the state axis only using getter and setter closures. The action type is unchanged.
    ///
    /// Use when the action type is already correct but the state needs embedding into a larger struct:
    ///
    /// ```swift
    /// let lifted = counterReducer.lift(
    ///     stateGetter: { $0.counter },
    ///     stateSetter: { $0.counter = $1 }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - stateGetter: Reads the local `StateType` from the global state.
    ///   - stateSetter: Writes the local `StateType` back into the global state.
    /// - Returns: A `Reducer<ActionType, GlobalState>` that applies this reducer's mutation
    ///   through the getter/setter pair.
    public func lift<GlobalState: Sendable>(
        stateGetter: @escaping @Sendable (GlobalState) -> StateType,
        stateSetter: @escaping @Sendable (inout GlobalState, StateType) -> Void
    ) -> Reducer<ActionType, GlobalState> {
        .reduce { action in Lens(get: stateGetter, setMut: stateSetter).lift(self.reduce(action)) }
    }
}

// MARK: - Lift (WritableKeyPath — state only)

extension Reducer {
    /// Lifts the state axis only using a `WritableKeyPath`. The action type is unchanged.
    ///
    /// This is the most ergonomic way to embed a feature reducer into a parent reducer when
    /// the action type is already correct:
    ///
    /// ```swift
    /// let lifted = counterReducer.lift(state: \AppState.counter)
    /// ```
    ///
    /// - Parameter state: A `WritableKeyPath<GlobalState, StateType>` identifying the
    ///   sub-state property.
    /// - Returns: A `Reducer<ActionType, GlobalState>` that reads and writes only the
    ///   property identified by `state`.
    public func lift<GlobalState>(
        state: WritableKeyPath<GlobalState, StateType>
    ) -> Reducer<ActionType, GlobalState> {
        .reduce { action in EndoMut { globalState in self.reduce(action)(&globalState[keyPath: state]) } }
    }
}

// MARK: - Lift (optics — action: Prism)

extension Reducer {
    /// Lifts the action axis only using a `Prism`. The state type is unchanged.
    ///
    /// The reducer is a no-op for global actions not matched by the prism:
    ///
    /// ```swift
    /// let lifted = counterReducer.lift(action: AppAction.prism.counter)
    /// ```
    ///
    /// - Parameter prism: A `Prism<GlobalAction, ActionType>` where `preview` extracts the
    ///   local action from a global action.
    /// - Returns: A `Reducer<GlobalAction, StateType>` that is a no-op for unmatched actions.
    public func lift<GlobalAction>(
        action prism: Prism<GlobalAction, ActionType>
    ) -> Reducer<GlobalAction, StateType> {
        .reduce { globalAction in
            guard let localAction = prism.preview(globalAction) else { return .identity }
            return self.reduce(localAction)
        }
    }

    /// Lifts both axes using a `Prism` for action and a `WritableKeyPath` for state.
    ///
    /// The most common lift pattern for feature reducers embedded in an app reducer:
    ///
    /// ```swift
    /// let lifted = counterReducer.lift(
    ///     action: AppAction.prism.counter,
    ///     state:  \AppState.counterState
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A `Prism<GlobalAction, ActionType>` for the action axis.
    ///   - keyPath: A `WritableKeyPath<GlobalState, StateType>` for the state axis.
    /// - Returns: A `Reducer<GlobalAction, GlobalState>` that is a no-op for unmatched actions.
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
    ///
    /// ```swift
    /// let lifted = counterReducer.lift(
    ///     action: AppAction.prism.counter,
    ///     state:  AppState.lens.counter
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A `Prism<GlobalAction, ActionType>` for the action axis.
    ///   - lens: A `Lens<GlobalState, StateType>` for the state axis.
    /// - Returns: A `Reducer<GlobalAction, GlobalState>` that is a no-op for unmatched actions.
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
    ///
    /// The reducer is a no-op both when the action prism does not match and when the state
    /// prism's focused enum case is absent:
    ///
    /// ```swift
    /// let lifted = loggedInReducer.lift(
    ///     action: AppAction.prism.loggedIn,
    ///     state:  AppState.prism.loggedIn
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - actionPrism: A `Prism<GlobalAction, ActionType>` for the action axis.
    ///   - statePrism: A `Prism<GlobalState, StateType>` for the state axis.
    /// - Returns: A `Reducer<GlobalAction, GlobalState>` that is a no-op for unmatched actions
    ///   or when the state prism's focused case is absent.
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
    ///
    /// The reducer is a no-op both when the action prism does not match and when the traversal's
    /// focus is absent:
    ///
    /// ```swift
    /// let lifted = itemReducer.lift(
    ///     action: AppAction.prism.item,
    ///     state:  AppState.traversal.selectedItem
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A `Prism<GlobalAction, ActionType>` for the action axis.
    ///   - traversal: An `AffineTraversal<GlobalState, StateType>` for the state axis.
    /// - Returns: A `Reducer<GlobalAction, GlobalState>` that is a no-op for unmatched actions
    ///   or when the traversal's focus is absent.
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
    /// Lifts the action axis only using an `AffineTraversal`. The state type is unchanged.
    ///
    /// Use when the action extraction is not a simple prism but can be expressed as an affine
    /// traversal (e.g., focusing on a property of an associated value):
    ///
    /// ```swift
    /// let lifted = counterReducer.lift(action: AppAction.traversal.counterValue)
    /// ```
    ///
    /// - Parameter traversal: An `AffineTraversal<GlobalAction, ActionType>` for the action axis.
    /// - Returns: A `Reducer<GlobalAction, StateType>` that is a no-op for unmatched actions.
    public func lift<GlobalAction>(
        action traversal: AffineTraversal<GlobalAction, ActionType>
    ) -> Reducer<GlobalAction, StateType> {
        .reduce { globalAction in
            guard let localAction = traversal.preview(globalAction) else { return .identity }
            return self.reduce(localAction)
        }
    }

    /// Lifts both axes using an `AffineTraversal` for action and a `WritableKeyPath` for state.
    ///
    /// - Parameters:
    ///   - traversal: An `AffineTraversal<GlobalAction, ActionType>` for the action axis.
    ///   - keyPath: A `WritableKeyPath<GlobalState, StateType>` for the state axis.
    /// - Returns: A `Reducer<GlobalAction, GlobalState>` that is a no-op for unmatched actions.
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
    ///
    /// - Parameters:
    ///   - traversal: An `AffineTraversal<GlobalAction, ActionType>` for the action axis.
    ///   - lens: A `Lens<GlobalState, StateType>` for the state axis.
    /// - Returns: A `Reducer<GlobalAction, GlobalState>` that is a no-op for unmatched actions.
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
    ///
    /// The reducer is a no-op when either the action traversal has no focus or the state
    /// prism's focused case is absent.
    ///
    /// - Parameters:
    ///   - traversal: An `AffineTraversal<GlobalAction, ActionType>` for the action axis.
    ///   - prism: A `Prism<GlobalState, StateType>` for the state axis.
    /// - Returns: A `Reducer<GlobalAction, GlobalState>` that is a no-op for unmatched inputs.
    public func lift<GlobalAction, GlobalState>(
        action traversal: AffineTraversal<GlobalAction, ActionType>,
        state prism: Prism<GlobalState, StateType>
    ) -> Reducer<GlobalAction, GlobalState> {
        .reduce { globalAction in
            guard let localAction = traversal.preview(globalAction) else { return .identity }
            return prism.lift(self.reduce(localAction))
        }
    }

    /// Lifts both axes using an `AffineTraversal` for both action and state.
    ///
    /// The most general optic-based lift: the reducer is a no-op when either traversal
    /// has no focus.
    ///
    /// - Parameters:
    ///   - actionTraversal: An `AffineTraversal<GlobalAction, ActionType>` for the action axis.
    ///   - stateTraversal: An `AffineTraversal<GlobalState, StateType>` for the state axis.
    /// - Returns: A `Reducer<GlobalAction, GlobalState>` that is a no-op for unmatched inputs.
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
    /// Lifts the state axis only using a `Lens`. The action type is unchanged.
    ///
    /// ```swift
    /// let lifted = counterReducer.lift(state: AppState.lens.counter)
    /// ```
    ///
    /// - Parameter lens: A `Lens<GlobalState, StateType>` for the state axis.
    /// - Returns: A `Reducer<ActionType, GlobalState>` that applies this reducer's mutation
    ///   through the lens.
    public func lift<GlobalState>(
        state lens: Lens<GlobalState, StateType>
    ) -> Reducer<ActionType, GlobalState> {
        .reduce { action in lens.lift(self.reduce(action)) }
    }

    /// Lifts the state axis only using a `Prism`. The action type is unchanged.
    ///
    /// The reducer is a no-op when the prism's focused enum case is absent:
    ///
    /// ```swift
    /// let lifted = authReducer.lift(state: AppState.prism.authenticated)
    /// ```
    ///
    /// - Parameter prism: A `Prism<GlobalState, StateType>` for the state axis.
    /// - Returns: A `Reducer<ActionType, GlobalState>` that is a no-op when the focused
    ///   case is absent from the global state.
    public func lift<GlobalState>(
        state prism: Prism<GlobalState, StateType>
    ) -> Reducer<ActionType, GlobalState> {
        .reduce { action in prism.lift(self.reduce(action)) }
    }

    /// Lifts the state axis only using an `AffineTraversal`. The action type is unchanged.
    ///
    /// The reducer is a no-op when the traversal's focus is absent:
    ///
    /// ```swift
    /// let lifted = itemReducer.lift(state: AppState.traversal.selectedItem)
    /// ```
    ///
    /// - Parameter traversal: An `AffineTraversal<GlobalState, StateType>` for the state axis.
    /// - Returns: A `Reducer<ActionType, GlobalState>` that is a no-op when the focus is absent.
    public func lift<GlobalState>(
        state traversal: AffineTraversal<GlobalState, StateType>
    ) -> Reducer<ActionType, GlobalState> {
        .reduce { action in traversal.lift(self.reduce(action)) }
    }
}
