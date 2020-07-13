extension AnyMiddleware {
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> AnyMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                inputAction: inputActionMap,
                outputAction: outputActionMap,
                state: stateMap
            ).eraseToAnyMiddleware()
        }

        return LiftMiddleware(
            middleware: self,
            inputActionMap: inputActionMap,
            outputActionMap: outputActionMap,
            stateMap: stateMap
        ).eraseToAnyMiddleware()
    }

    public func lift<GlobalOutputActionType, GlobalStateType>(
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> AnyMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                outputAction: outputActionMap,
                state: stateMap
            ).eraseToAnyMiddleware()
        }

        return LiftMiddleware(
            middleware: self,
            inputActionMap: { $0 },
            outputActionMap: outputActionMap,
            stateMap: stateMap
        ).eraseToAnyMiddleware()
    }

    public func lift<GlobalInputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> AnyMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                inputAction: inputActionMap,
                state: stateMap
            ).eraseToAnyMiddleware()
        }

        return LiftMiddleware(
            middleware: self,
            inputActionMap: inputActionMap,
            outputActionMap: { $0 },
            stateMap: stateMap
        ).eraseToAnyMiddleware()
    }

    public func lift<GlobalInputActionType, GlobalOutputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> AnyMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                inputAction: inputActionMap,
                outputAction: outputActionMap
            ).eraseToAnyMiddleware()
        }

        return LiftMiddleware(
            middleware: self,
            inputActionMap: inputActionMap,
            outputActionMap: outputActionMap,
            stateMap: { $0 }
        ).eraseToAnyMiddleware()
    }

    public func lift<GlobalInputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?
    ) -> AnyMiddleware<GlobalInputActionType, OutputActionType, StateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                inputAction: inputActionMap
            ).eraseToAnyMiddleware()
        }

        return LiftMiddleware(
            middleware: self,
            inputActionMap: inputActionMap,
            outputActionMap: { $0 },
            stateMap: { $0 }
        ).eraseToAnyMiddleware()
    }

    public func lift<GlobalOutputActionType>(
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> AnyMiddleware<InputActionType, GlobalOutputActionType, StateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                outputAction: outputActionMap
            ).eraseToAnyMiddleware()
        }

        return LiftMiddleware(
            middleware: self,
            inputActionMap: { $0 },
            outputActionMap: outputActionMap,
            stateMap: { $0 }
        ).eraseToAnyMiddleware()
    }

    public func lift<GlobalStateType>(
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> AnyMiddleware<InputActionType, OutputActionType, GlobalStateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                state: stateMap
            ).eraseToAnyMiddleware()
        }

        return LiftMiddleware(
            middleware: self,
            inputActionMap: { $0 },
            outputActionMap: { $0 },
            stateMap: stateMap
        ).eraseToAnyMiddleware()
    }
}
