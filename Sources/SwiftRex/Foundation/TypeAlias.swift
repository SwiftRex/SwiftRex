/**
 Zero-argument function that returns the current state. <br/>
 `() -> StateType`
 */
public typealias GetState<StateType> = () -> StateType

/**
 State reducer: takes current state and an action, computes the new state. <br/>
 `(ActionType, StateType) -> StateType`
 */
public typealias ReduceFunction<ActionType, StateType> = (ActionType, StateType) -> StateType
