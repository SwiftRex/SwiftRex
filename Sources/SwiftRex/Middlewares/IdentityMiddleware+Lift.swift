extension IdentityMiddleware {
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> IdentityMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType> {
        .init()
    }

    public func lift<GlobalOutputActionType, GlobalStateType>(
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> IdentityMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType> {
        .init()
    }

    public func lift<GlobalInputActionType, GlobalStateType>(
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> IdentityMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType> {
        .init()
    }

    public func lift<GlobalInputActionType, GlobalOutputActionType>(
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> IdentityMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType> {
        .init()
    }

    public func lift<GlobalInputActionType>(
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?
    ) -> IdentityMiddleware<GlobalInputActionType, OutputActionType, StateType> {
        .init()
    }

    public func lift<GlobalOutputActionType>(
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> IdentityMiddleware<InputActionType, GlobalOutputActionType, StateType> {
        .init()
    }

    public func lift<GlobalStateType>(
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> IdentityMiddleware<InputActionType, OutputActionType, GlobalStateType> {
        .init()
    }
}

