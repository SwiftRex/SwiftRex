extension IdentityMiddleware {
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputAction: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction: @escaping (OutputActionType) -> GlobalOutputActionType,
        state: @escaping (GlobalStateType) -> StateType
    ) -> IdentityMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType> {
        .init()
    }

    public func lift<GlobalOutputActionType, GlobalStateType>(
        outputAction: @escaping (OutputActionType) -> GlobalOutputActionType,
        state: @escaping (GlobalStateType) -> StateType
    ) -> IdentityMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType> {
        .init()
    }

    public func lift<GlobalInputActionType, GlobalStateType>(
        inputAction: @escaping (GlobalInputActionType) -> InputActionType?,
        state: @escaping (GlobalStateType) -> StateType
    ) -> IdentityMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType> {
        .init()
    }

    public func lift<GlobalInputActionType, GlobalOutputActionType>(
        inputAction: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> IdentityMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType> {
        .init()
    }

    public func lift<GlobalInputActionType>(
        inputAction: @escaping (GlobalInputActionType) -> InputActionType?
    ) -> IdentityMiddleware<GlobalInputActionType, OutputActionType, StateType> {
        .init()
    }

    public func lift<GlobalOutputActionType>(
        outputAction: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> IdentityMiddleware<InputActionType, GlobalOutputActionType, StateType> {
        .init()
    }

    public func lift<GlobalStateType>(
        state: @escaping (GlobalStateType) -> StateType
    ) -> IdentityMiddleware<InputActionType, OutputActionType, GlobalStateType> {
        .init()
    }
}
