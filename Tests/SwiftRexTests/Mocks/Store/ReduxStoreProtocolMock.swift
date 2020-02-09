import Foundation

typealias IsoMiddlewareMock<Action, State> = MiddlewareMock<Action, Action, State>

extension ReduxStoreProtocolMock {
    typealias MiddlewareType = IsoMiddlewareMock<ActionType, StateType>
}
