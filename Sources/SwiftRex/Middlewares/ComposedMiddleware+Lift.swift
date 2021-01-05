extension ComposedMiddleware {
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> ComposedMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType> {
        var composed = ComposedMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>()

        middlewares.lazy.map {
            $0.lift(
                inputAction: inputActionMap,
                outputAction: outputActionMap,
                state: stateMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }

    public func lift<GlobalOutputActionType, GlobalStateType>(
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> ComposedMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType> {
        var composed = ComposedMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType>()

        middlewares.lazy.map {
            $0.lift(
                outputAction: outputActionMap,
                state: stateMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }

    public func lift<GlobalInputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> ComposedMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType> {
        var composed = ComposedMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType>()

        middlewares.lazy.map {
            $0.lift(
                inputAction: inputActionMap,
                state: stateMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }

    public func lift<GlobalInputActionType, GlobalOutputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> ComposedMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType> {
        var composed = ComposedMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType>()

        middlewares.lazy.map {
            $0.lift(
                inputAction: inputActionMap,
                outputAction: outputActionMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }

    public func lift<GlobalInputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?
    ) -> ComposedMiddleware<GlobalInputActionType, OutputActionType, StateType> {
        var composed = ComposedMiddleware<GlobalInputActionType, OutputActionType, StateType>()

        middlewares.lazy.map {
            $0.lift(
                inputAction: inputActionMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }

    public func lift<GlobalOutputActionType>(
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> ComposedMiddleware<InputActionType, GlobalOutputActionType, StateType> {
        var composed = ComposedMiddleware<InputActionType, GlobalOutputActionType, StateType>()

        middlewares.lazy.map {
            $0.lift(
                outputAction: outputActionMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }

    public func lift<GlobalStateType>(
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> ComposedMiddleware<InputActionType, OutputActionType, GlobalStateType> {
        var composed = ComposedMiddleware<InputActionType, OutputActionType, GlobalStateType>()

        middlewares.lazy.map {
            $0.lift(
                state: stateMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }
}
