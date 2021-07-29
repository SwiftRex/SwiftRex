import Foundation

typealias IsoMiddlewareMock<Action, State> = MiddlewareProtocolMock<Action, Action, State>

extension ReduxStoreProtocolMock {
    typealias MiddlewareType = IsoMiddlewareMock<ActionType, StateType>
}
