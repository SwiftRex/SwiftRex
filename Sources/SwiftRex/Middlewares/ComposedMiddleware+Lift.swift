extension ComposedMiddleware {
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> ComposedMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType> {
        var composed = ComposedMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>()

        middlewares.lazy.map {
            $0.lift(
                inputActionMap: inputActionMap,
                outputActionMap: outputActionMap,
                stateMap: stateMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }

    public func lift<GlobalOutputActionType, GlobalStateType>(
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> ComposedMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType> {
        var composed = ComposedMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType>()

        middlewares.lazy.map {
            $0.lift(
                outputActionMap: outputActionMap,
                stateMap: stateMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }

    public func lift<GlobalInputActionType, GlobalStateType>(
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> ComposedMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType> {
        var composed = ComposedMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType>()

        middlewares.lazy.map {
            $0.lift(
                inputActionMap: inputActionMap,
                stateMap: stateMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }

    public func lift<GlobalInputActionType, GlobalOutputActionType>(
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> ComposedMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType> {
        var composed = ComposedMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType>()

        middlewares.lazy.map {
            $0.lift(
                inputActionMap: inputActionMap,
                outputActionMap: outputActionMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }

    public func lift<GlobalInputActionType>(
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?
    ) -> ComposedMiddleware<GlobalInputActionType, OutputActionType, StateType> {
        var composed = ComposedMiddleware<GlobalInputActionType, OutputActionType, StateType>()

        middlewares.lazy.map {
            $0.lift(
                inputActionMap: inputActionMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }

    public func lift<GlobalOutputActionType>(
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> ComposedMiddleware<InputActionType, GlobalOutputActionType, StateType> {
        var composed = ComposedMiddleware<InputActionType, GlobalOutputActionType, StateType>()

        middlewares.lazy.map {
            $0.lift(
                outputActionMap: outputActionMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }

    public func lift<GlobalStateType>(
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> ComposedMiddleware<InputActionType, OutputActionType, GlobalStateType> {
        var composed = ComposedMiddleware<InputActionType, OutputActionType, GlobalStateType>()

        middlewares.lazy.map {
            $0.lift(
                stateMap: stateMap
            )
        }.forEach { composed.append(middleware: $0) }

        return composed
    }
}
