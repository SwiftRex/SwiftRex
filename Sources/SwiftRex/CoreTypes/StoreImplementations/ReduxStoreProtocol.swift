import Foundation

public protocol ReduxStoreProtocol: class, StoreType {
    associatedtype MiddlewareType: Middleware
        where MiddlewareType.StateType == StateType, MiddlewareType.ActionType == ActionType
    var pipeline: ReduxPipelineWrapper<MiddlewareType> { get }
}

extension ReduxStoreProtocol {
    public func dispatch(_ action: ActionType) {
        pipeline.dispatch(action)
    }
}
