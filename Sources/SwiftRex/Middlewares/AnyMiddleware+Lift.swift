extension AnyMiddleware {
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> AnyMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                inputActionMap: inputActionMap,
                outputActionMap: outputActionMap,
                stateMap: stateMap
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
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> AnyMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                outputActionMap: outputActionMap,
                stateMap: stateMap
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
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> AnyMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                inputActionMap: inputActionMap,
                stateMap: stateMap
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
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> AnyMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                inputActionMap: inputActionMap,
                outputActionMap: outputActionMap
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
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?
    ) -> AnyMiddleware<GlobalInputActionType, OutputActionType, StateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                inputActionMap: inputActionMap
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
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> AnyMiddleware<InputActionType, GlobalOutputActionType, StateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                outputActionMap: outputActionMap
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
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> AnyMiddleware<InputActionType, OutputActionType, GlobalStateType> {
        if isIdentity { return IdentityMiddleware().eraseToAnyMiddleware() }

        if let composed = isComposed {
            return composed.lift(
                stateMap: stateMap
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
