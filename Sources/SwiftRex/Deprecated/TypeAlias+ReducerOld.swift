import Foundation

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
