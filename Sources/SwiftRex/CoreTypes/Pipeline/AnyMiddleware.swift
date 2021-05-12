import Foundation

/// Erases the protocol `Middleware`. Please check its documentation for more information.
public struct AnyMiddleware<InputActionType, OutputActionType, StateType>: MiddlewareProtocol {
    private let _handle: (InputActionType, ActionSource, @escaping GetState<StateType>) -> IO<OutputActionType>
    private let _receiveContext: (@escaping GetState<StateType>, AnyActionHandler<OutputActionType>) -> Void
    // It doesn't completely erase the type for identity or composed, for performance reasons
    // That way, when we compose again, we discard identity or flattenize the composed middleware
    let isIdentity: Bool
    let isComposed: ComposedMiddleware<InputActionType, OutputActionType, StateType>?

    public init(receiveContext: @escaping (@escaping GetState<StateType>, AnyActionHandler<OutputActionType>) -> Void = { _, _ in },
                handle: @escaping (InputActionType, ActionSource, @escaping GetState<StateType>) -> IO<OutputActionType>) {
        self.init(receiveContext: receiveContext, handle: handle, isIdentity: false)
    }

    private init(receiveContext: @escaping (@escaping GetState<StateType>, AnyActionHandler<OutputActionType>) -> Void,
                 handle: @escaping (InputActionType, ActionSource, @escaping GetState<StateType>) -> IO<OutputActionType>,
                 isIdentity: Bool) {
        self._handle = handle
        self._receiveContext = receiveContext
        self.isIdentity = isIdentity
        self.isComposed = nil
    }

    private init(composed: ComposedMiddleware<InputActionType, OutputActionType, StateType>) {
        self._handle = composed.handle
        self._receiveContext = composed.receiveContext
        self.isIdentity = false
        self.isComposed = composed
    }

    public init<M: MiddlewareProtocol>(_ realMiddleware: M)
    where M.InputActionType == InputActionType, M.OutputActionType == OutputActionType, M.StateType == StateType {
        if let alreadyErased = realMiddleware as? AnyMiddleware<InputActionType, OutputActionType, StateType> {
            self = alreadyErased
            return
        }
        if let composed = realMiddleware as? ComposedMiddleware<InputActionType, OutputActionType, StateType> {
            self.init(composed: composed)
            return
        }
        let isIdentity = realMiddleware is IdentityMiddleware<InputActionType, OutputActionType, StateType>
        self.init(receiveContext: realMiddleware.receiveContext, handle: realMiddleware.handle, isIdentity: isIdentity)
    }

    @available(
        *,
        deprecated,
        message: """
                 Instead of relying on receiveContext, please use the getState from handle(action) function,
                 and when returning IO from the same handle(action) function use the output from the closure
                 """
    )
    public func receiveContext(getState: @escaping () -> StateType, output: AnyActionHandler<OutputActionType>) {
        _receiveContext(getState, output)
    }

    public func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType> {
        _handle(action, dispatcher, state)
    }
}

extension MiddlewareProtocol {
    public func eraseToAnyMiddleware() -> AnyMiddleware<InputActionType, OutputActionType, StateType> {
        AnyMiddleware(self)
    }
}
