import Foundation

// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = StateType
// sourcery: AutoMockableGeneric = ActionType
// sourcery: AutoMockableSkip = "dispatch(_ dispatchedAction: DispatchedAction<ActionType>)"
public protocol ReduxStoreProtocol: AnyObject, StoreType {
    associatedtype MiddlewareType: MiddlewareProtocol
        where MiddlewareType.StateType == StateType,
              MiddlewareType.InputActionType == ActionType,
              MiddlewareType.OutputActionType == ActionType

    var pipeline: ReduxPipelineWrapper<MiddlewareType> { get }
}

extension ReduxStoreProtocol {
    public func dispatch(_ dispatchedAction: DispatchedAction<ActionType>) {
        pipeline.dispatch(dispatchedAction)
    }
}
