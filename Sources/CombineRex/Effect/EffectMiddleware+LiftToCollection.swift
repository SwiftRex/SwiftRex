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
        EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies>(
            dependencies: self.dependencies,
            actionHandler: { action, dispatcher, state -> IO<GlobalAction> in
                guard let itemAction = actionMap(action) else { return .pure() }
                let getStateItem = { stateCollection(state()).first(where: { $0.id == itemAction.id }) }
                guard let itemState = getStateItem() else { return .pure() }

                let getState = { getStateItem() ?? itemState }

                return self.handle(
                    action: itemAction.action,
                    from: dispatcher,
                    state: getState
                ).map { (outputAction: OutputActionType) -> GlobalAction in
                    outputMap(.init(id: itemAction.id, action: outputAction))
                }
            }
        )
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware where StateType: Identifiable, InputActionType == OutputActionType {
    public func liftToCollection<GlobalAction, GlobalState, CollectionState: MutableCollection>(
        action actionMap: WritableKeyPath<GlobalAction, ElementIDAction<StateType.ID, InputActionType>?>,
        stateCollection: KeyPath<GlobalState, CollectionState>
    ) -> EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies> where CollectionState.Element == StateType {
        EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies>(
            dependencies: self.dependencies,
            actionHandler: { action, dispatcher, state in
                guard let itemAction = action[keyPath: actionMap] else { return .pure() }
                let getStateItem = { state()[keyPath: stateCollection].first(where: { $0.id == itemAction.id }) }
                guard let itemState = getStateItem() else { return .pure() }

                let getState = { getStateItem() ?? itemState }

                return self.handle(
                    action: itemAction.action,
                    from: dispatcher,
                    state: getState
                ).map { (outputAction: OutputActionType) -> GlobalAction in
                    var newAction = action
                    newAction[keyPath: actionMap] = .init(id: itemAction.id, action: outputAction)
                    return newAction
                }
            }
        )
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

            return EffectMiddleware(
                dependencies: dependencies,
                actionHandler: { action, dispatcher, state -> IO<GlobalAction> in
                    guard let itemAction = actionMap(action) else { return .pure() }
                    let getStateItem = { stateCollection(state()).first(where: { $0.id == itemAction.id }) }
                    guard let itemState = getStateItem() else { return .pure() }

                    let outputContramap = { (outputAction: ItemOutputActionType) -> GlobalAction in
                        outputMap(.init(id: itemAction.id, action: outputAction))
                    }

                    let getState = { getStateItem() ?? itemState }

                    return itemMiddleware.handle(
                        action: itemAction.action,
                        from: dispatcher,
                        state: getState
                    ).map(outputContramap)
                }
            )
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

            return EffectMiddleware(
                dependencies: dependencies,
                actionHandler: { action, dispatcher, state in
                    guard let itemAction = action[keyPath: actionMap] else { return .pure() }
                    let getStateItem = { state()[keyPath: stateCollection].first(where: { $0.id == itemAction.id }) }
                    guard let itemState = getStateItem() else { return .pure() }

                    let outputContramap = { (outputAction: ItemActionType) -> GlobalAction in
                        var newAction = action
                        newAction[keyPath: actionMap] = .init(id: itemAction.id, action: outputAction)
                        return newAction
                    }

                    let getState = { getStateItem() ?? itemState }

                    return itemMiddleware.handle(
                        action: itemAction.action,
                        from: dispatcher,
                        state: getState
                    ).map(outputContramap)
                }
            )
        }
    }
}
#endif
