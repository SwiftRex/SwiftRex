import Foundation

/// Erases the protocol `Middleware`. Please check its documentation for more information.
public struct AnyMiddleware<InputActionType, OutputActionType, StateType>: Middleware {
    private let _handle: (InputActionType, ActionSource, inout AfterReducer) -> Void
    private let _receiveContext: (@escaping GetState<StateType>, AnyActionHandler<OutputActionType>) -> Void

    public init(handle: @escaping (InputActionType, ActionSource, inout AfterReducer) -> Void,
                receiveContext: @escaping (@escaping GetState<StateType>, AnyActionHandler<OutputActionType>) -> Void) {
        self._handle = handle
        self._receiveContext = receiveContext
    }

    public init<M: Middleware>(_ realMiddleware: M)
    where M.InputActionType == InputActionType, M.OutputActionType == OutputActionType, M.StateType == StateType {
        self.init(handle: realMiddleware.handle, receiveContext: realMiddleware.receiveContext)
    }

    public func receiveContext(getState: @escaping () -> StateType, output: AnyActionHandler<OutputActionType>) {
        _receiveContext(getState, output)
    }

    public func handle(action: InputActionType, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        _handle(action, dispatcher, &afterReducer)
    }
}

extension Middleware {
    public func eraseToAnyMiddleware() -> AnyMiddleware<InputActionType, OutputActionType, StateType> {
        AnyMiddleware(self)
    }
}
