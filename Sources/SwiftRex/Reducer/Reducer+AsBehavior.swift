import DataStructure

extension Reducer {
    /// Wraps this reducer as a `Behavior` with no effects.
    ///
    /// The `Environment` type parameter is left open so the result can be composed
    /// with `Behavior(reducer:middleware:)` or lifted without an extra `liftEnvironment` call.
    ///
    /// ```swift
    /// let b: Behavior<Action, State, AppEnvironment> = myReducer.asBehavior()
    /// ```
    public func asBehavior<Environment: Sendable>() -> Behavior<ActionType, StateType, Environment> {
        Behavior { action, _ in
            Consequence(mutation: self.reduce(action.action), effect: Reader { _ in .empty })
        }
    }
}
