/**
 Zero-argument function that returns the current state. <br/>
 `() -> StateType`
 */
public typealias GetState<StateType> = () -> StateType

/**
 State reducer: takes current state and an action, computes the new state. <br/>
 `(StateType, ActionProtocol) -> StateType`
 */
public typealias ReduceFunction<ActionType, StateType> = (StateType, ActionType) -> StateType
