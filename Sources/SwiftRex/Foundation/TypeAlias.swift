/**
 Zero-argument function that returns the current state. <br/>
 `() -> StateType`
 */
public typealias GetState<StateType> = () -> StateType

/**
 State reducer: takes current state and an action, computes the new state. <br/>
 `(StateType, ActionProtocol) -> StateType`
 */
public typealias ReduceFunction<StateType> = (StateType, ActionProtocol) -> StateType

/**
 A function that calls the next event handler in the chain. <br/>
 `(EventProtocol, () -> StateType) -> Void`
 */
public typealias NextEventHandler<StateType> = (EventProtocol, @escaping GetState<StateType>) -> Void

/**
 A function that calls the next action handler in the chain. <br/>
 `(ActionProtocol, () -> StateType) -> Void`
 */
public typealias NextActionHandler<StateType> = (ActionProtocol, @escaping GetState<StateType>) -> Void
