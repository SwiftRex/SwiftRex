@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension MiddlewareProtocol where StateType: Identifiable {
    public func liftToCollection<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, CollectionState: MutableCollection>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> ElementIDAction<StateType.ID, InputActionType>?,
        outputAction outputActionMap: @escaping (ElementIDAction<StateType.ID, OutputActionType>) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> CollectionState
    ) -> LiftToCollectionMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, CollectionState, Self> {
        .init(
            middleware: self,
            onAction: { partMiddleware, inputAction, actionSource, getState in
                guard let itemAction = inputActionMap(inputAction) else { return .pure() }
                let getStateItem = { stateMap(getState()).first(where: { $0.id == itemAction.id }) }
                guard let itemState = getStateItem() else { return .pure() }

                let getState = { getStateItem() ?? itemState }

                return partMiddleware.handle(action: itemAction.action, from: actionSource, state: getState)
                    .map { (outputAction: Self.OutputActionType) -> GlobalOutputActionType in
                        outputActionMap(.init(id: itemAction.id, action: outputAction))
                    }
            }
        )
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension MiddlewareProtocol where StateType: Identifiable, InputActionType == OutputActionType {
    public func liftToCollection<GlobalActionType, GlobalStateType, CollectionState: MutableCollection>(
        action actionMap: WritableKeyPath<GlobalActionType, ElementIDAction<StateType.ID, InputActionType>?>,
        stateCollection: KeyPath<GlobalStateType, CollectionState>
    ) -> LiftToCollectionMiddleware<GlobalActionType, GlobalActionType, GlobalStateType, CollectionState, Self> {
        .init(middleware: self) { partMiddleware, inputAction, actionSource, getState in
            guard let itemAction = inputAction[keyPath: actionMap] else { return .pure() }
            let getStateItem = { getState()[keyPath: stateCollection].first(where: { $0.id == itemAction.id }) }
            guard let itemState = getStateItem() else { return .pure() }

            let getState = { getStateItem() ?? itemState }

            return partMiddleware.handle(action: itemAction.action,
                                         from: actionSource,
                                         state: getState
            ).map { (outputAction: Self.OutputActionType) -> GlobalActionType in
                var newAction = inputAction
                newAction[keyPath: actionMap] = .init(id: itemAction.id, action: outputAction)
                return newAction
            }
        }
    }
}
