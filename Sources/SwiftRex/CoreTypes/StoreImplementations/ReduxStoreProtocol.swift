import Foundation

// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = ActionType
// sourcery: AutoMockableGeneric = StateType
// sourcery: AutoMockableSkip = "dispatch(_ dispatchedAction: DispatchedAction<ActionType>)"
public protocol ReduxStoreProtocol: AnyObject, StoreType {
    associatedtype ActionType
    associatedtype StateType

    var pipeline: ReduxPipelineWrapper<ActionType, StateType> { get }
}

extension ReduxStoreProtocol {
    public func dispatch(_ dispatchedAction: DispatchedAction<ActionType>) {
        pipeline.dispatch(dispatchedAction)
    }
}
