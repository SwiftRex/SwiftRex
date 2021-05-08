import Foundation

extension Reducer {
    /**
     Reducer initializer takes only the underlying function `(ActionType, StateType) -> StateType` that is the reducer
     function itself.
     - Parameters:
       - reduce: a pure function that is gonna be wrapped in a monoid container, and that calculates the new state from
                 an action and the old state.
     */
    @available(
        *,
        deprecated,
        message: "Use `Reducer.reduce` instead of `Reducer.init`. Mutable inout state will improve performance. SwiftRex 1.0 will remove this init"
    )
    public init(_ reduce: @escaping ReduceFunction<ActionType, StateType>) {
        self.init { action, state in
            state = reduce(action, state)
        }
    }
}
