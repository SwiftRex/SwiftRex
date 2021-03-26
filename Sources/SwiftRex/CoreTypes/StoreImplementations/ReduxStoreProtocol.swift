import Foundation

// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = StateType
// sourcery: AutoMockableGeneric = ActionType
// sourcery: AutoMockableSkip = "dispatch(_ action: ActionType, from dispatcher: ActionSource)"
public protocol ReduxStoreProtocol: AnyObject, StoreType {
    associatedtype MiddlewareType: Middleware
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
