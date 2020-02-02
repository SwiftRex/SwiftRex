import Foundation

public struct AnyMiddleware<InputActionType, OutputActionType, StateType>: Middleware {
    private let _handle: (InputActionType) -> AfterReducer
    private let _receiveContext: (@escaping GetState<StateType>, AnyActionHandler<OutputActionType>) -> Void

    public init(handle: @escaping (InputActionType) -> AfterReducer,
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

    public func handle(action: InputActionType) -> AfterReducer {
        _handle(action)
    }
}

extension Middleware {
    public func eraseToAnyMiddleware() -> AnyMiddleware<InputActionType, OutputActionType, StateType> {
        AnyMiddleware(self)
    }
}
