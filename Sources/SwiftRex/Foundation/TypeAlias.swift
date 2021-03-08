/**
 Zero-argument function that returns the current state. <br/>
 `() -> StateType`
 */
public typealias GetState<StateType> = () -> StateType

/**
 State reducer: takes current state and an action, computes the new state. <br/>
 `(ActionType, StateType) -> StateType`
 */
@available(
    *,
    deprecated,
    message: "Use `MutableReduceFunction` instead of `ReduceFunction`. The inout state improves performance. SwiftRex 1.0 will remove this typealias"
)
public typealias ReduceFunction<ActionType, StateType> = (ActionType, StateType) -> StateType

/**
 State reducer: takes inout version of the current state and an action, computes the new state changing the provided mutable state. <br/>
 `(ActionType, inout StateType) -> Void`
 */
public typealias MutableReduceFunction<ActionType, StateType> = (ActionType, inout StateType) -> Void
