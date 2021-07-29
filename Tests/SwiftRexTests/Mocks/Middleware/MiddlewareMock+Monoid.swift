@testable import SwiftRex

typealias MiddlewareMock = MiddlewareProtocolMock

extension MiddlewareProtocolMock {
    static func <> (lhs: MiddlewareProtocolMock<InputActionType, OutputActionType, StateType>,
                    rhs: MiddlewareProtocolMock<InputActionType, OutputActionType, StateType>)
    -> MiddlewareProtocolMock<InputActionType, OutputActionType, StateType> {
        let combined = MiddlewareProtocolMock<InputActionType, OutputActionType, StateType>()
        combined.handleActionFromStateClosure = { action, dispatcher, state in
            let io1 = lhs.handle(action: action, from: dispatcher, state: state)
            let io2 = rhs.handle(action: action, from: dispatcher, state: state)
            return io1 <> io2
        }
        return combined
    }
}
