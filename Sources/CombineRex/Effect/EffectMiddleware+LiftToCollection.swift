#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware where StateType: Identifiable {
    public func liftToCollection<GlobalAction, GlobalState, CollectionState: MutableCollection>(
        inputAction actionMap: @escaping (GlobalAction) -> ElementIDAction<StateType.ID, InputActionType>?,
        outputAction outputMap: @escaping (ElementIDAction<StateType.ID, OutputActionType>) -> GlobalAction,
        stateCollection: @escaping (GlobalState) -> CollectionState
    ) -> EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies> where CollectionState.Element == StateType {
        EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies>.onAction { action, dispatcher, state in
            guard let itemAction = actionMap(action) else { return .doNothing }
            let getStateItem = { stateCollection(state()).first(where: { $0.id == itemAction.id }) }
            guard let itemState = getStateItem() else { return .doNothing }

            let getState = { getStateItem() ?? itemState }

            return self.onAction(
                itemAction.action,
                dispatcher,
                getState
            ).map { (outputAction: OutputActionType) -> GlobalAction in
                outputMap(.init(id: itemAction.id, action: outputAction))
            }
        }.inject(self.dependencies)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware where StateType: Identifiable, InputActionType == OutputActionType {
    public func liftToCollection<GlobalAction, GlobalState, CollectionState: MutableCollection>(
        action actionMap: WritableKeyPath<GlobalAction, ElementIDAction<StateType.ID, InputActionType>?>,
        stateCollection: KeyPath<GlobalState, CollectionState>
    ) -> EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies> where CollectionState.Element == StateType {
        EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies>.onAction { action, dispatcher, state in
            guard let itemAction = action[keyPath: actionMap] else { return .doNothing }
            let getStateItem = { state()[keyPath: stateCollection].first(where: { $0.id == itemAction.id }) }
            guard let itemState = getStateItem() else { return .doNothing }

            let getState = { getStateItem() ?? itemState }

            return self.onAction(
                itemAction.action,
                dispatcher,
                getState
            ).map { (outputAction: OutputActionType) -> GlobalAction in
                var newAction = action
                newAction[keyPath: actionMap] = .init(id: itemAction.id, action: outputAction)
                return newAction
            }
        }.inject(self.dependencies)
    }
}

extension MiddlewareReader {
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func liftToCollection<ItemInputActionType, ItemOutputActionType, ItemStateType, GlobalAction, GlobalState, CollectionState>(
        inputAction actionMap: @escaping (GlobalAction) -> ElementIDAction<ItemStateType.ID, ItemInputActionType>?,
        outputAction outputMap: @escaping (ElementIDAction<ItemStateType.ID, ItemOutputActionType>) -> GlobalAction,
        stateCollection: @escaping (GlobalState) -> CollectionState
    ) -> MiddlewareReader<Dependencies, EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies>>
    where CollectionState: MutableCollection,
          CollectionState.Element == ItemStateType,
          MiddlewareType == EffectMiddleware<ItemInputActionType, ItemOutputActionType, ItemStateType, Dependencies>,
          ItemStateType: Identifiable {
        .init { dependencies in
            let itemMiddleware = self.inject(dependencies)
            var hasTransferredContext = false
            var output: AnyActionHandler<GlobalAction>?

            return EffectMiddleware(
                dependencies: dependencies,
                onReceiveContext: { _, receivedOutput in
                    output = receivedOutput
                    hasTransferredContext = false
                }
            ) { action, dispatcher, state in
                guard let itemAction = actionMap(action),
                      let output = output else { return .doNothing }
                let getStateItem = { stateCollection(state()).first(where: { $0.id == itemAction.id }) }
                guard let itemState = getStateItem() else { return .doNothing }

                let outputContramap = { (outputAction: ItemOutputActionType) -> GlobalAction in
                    outputMap(.init(id: itemAction.id, action: outputAction))
                }

                let getState = { getStateItem() ?? itemState }

                if !hasTransferredContext {
                    hasTransferredContext = true
                    itemMiddleware.receiveContext(getState: getState, output: output.contramap(outputContramap))
                }

                return itemMiddleware.onAction(
                    itemAction.action,
                    dispatcher,
                    getState
                ).map(outputContramap)
            }
        }
    }
}

extension MiddlewareReader {
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func liftToCollection<ItemActionType, ItemStateType, GlobalAction, GlobalState, CollectionState: MutableCollection>(
        action actionMap: WritableKeyPath<GlobalAction, ElementIDAction<ItemStateType.ID, ItemActionType>?>,
        stateCollection: KeyPath<GlobalState, CollectionState>
    ) -> MiddlewareReader<Dependencies, EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies>>
    where CollectionState.Element == ItemStateType,
          MiddlewareType == EffectMiddleware<ItemActionType, ItemActionType, ItemStateType, Dependencies>,
          ItemStateType: Identifiable {
        .init { dependencies in
            let itemMiddleware = self.inject(dependencies)
            var hasTransferredContext = false
            var output: AnyActionHandler<GlobalAction>?

            return EffectMiddleware(
                dependencies: dependencies,
                onReceiveContext: { _, receivedOutput in
                    output = receivedOutput
                    hasTransferredContext = false
                }
            ) { action, dispatcher, state in
                guard let itemAction = action[keyPath: actionMap],
                      let output = output else { return .doNothing }
                let getStateItem = { state()[keyPath: stateCollection].first(where: { $0.id == itemAction.id }) }
                guard let itemState = getStateItem() else { return .doNothing }

                let outputContramap = { (outputAction: ItemActionType) -> GlobalAction in
                    var newAction = action
                    newAction[keyPath: actionMap] = .init(id: itemAction.id, action: outputAction)
                    return newAction
                }

                let getState = { getStateItem() ?? itemState }

                if !hasTransferredContext {
                    hasTransferredContext = true
                    itemMiddleware.receiveContext(getState: getState, output: output.contramap(outputContramap))
                }

                return itemMiddleware.onAction(
                    itemAction.action,
                    dispatcher,
                    getState
                ).map(outputContramap)
            }
        }
    }
}
#endif
