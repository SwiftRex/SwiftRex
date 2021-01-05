@testable import SwiftRex

extension MiddlewareMock {
    static func <> (lhs: MiddlewareMock<InputActionType, OutputActionType, StateType>,
                    rhs: MiddlewareMock<InputActionType, OutputActionType, StateType>)
    -> MiddlewareMock<InputActionType, OutputActionType, StateType> {
        let combined = MiddlewareMock<InputActionType, OutputActionType, StateType>()
        combined.receiveContextGetStateOutputClosure = { getState, output in
            lhs.receiveContextGetStateOutputClosure?(getState, output)
            rhs.receiveContextGetStateOutputClosure?(getState, output)
        }
        combined.handleActionFromAfterReducerClosure = { action, dispatcher, afterReducer in
            var lhsAfterReducer: AfterReducer = .doNothing()
            lhs.handle(action: action, from: dispatcher, afterReducer: &lhsAfterReducer)
            var rhsAfterReducer: AfterReducer = .doNothing()
            rhs.handle(action: action, from: dispatcher, afterReducer: &rhsAfterReducer)
            afterReducer = .do {
                lhsAfterReducer.reducerIsDone()
                rhsAfterReducer.reducerIsDone()
            }
        }
        return combined
    }
}
