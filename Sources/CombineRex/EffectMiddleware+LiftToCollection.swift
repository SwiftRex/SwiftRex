#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware where StateType: Identifiable {
    public func liftToCollection<GlobalAction, GlobalState, CollectionState: MutableCollection>(
        inputAction actionMap: @escaping (GlobalAction) -> ElementIDAction<StateType.ID, InputAction>?,
        outputAction outputMap: @escaping (ElementIDAction<StateType.ID, OutputAction>) -> GlobalAction,
        stateCollection: @escaping (GlobalState) -> CollectionState
    ) -> EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies> where CollectionState.Element == StateType {
        EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies>.onAction { action, state, context in
            guard let itemAction = actionMap(action) else { return .doNothing }
            guard let itemState = stateCollection(state).first(where: { $0.id == itemAction.id }) else { return .doNothing }

            let effectForItem = self.onAction(
                itemAction.action,
                itemState,
                .init(
                    dispatcher: context.dispatcher,
                    dependencies: context.dependencies,
                    toCancel: { hashable in .fireAndForget(context.toCancel(hashable)) }
                )
            )

            return effectForItem.map { (effectOutputForItem: EffectOutput<OutputAction>) in
                effectOutputForItem.map { (outputAction: OutputAction) in
                    outputMap(.init(id: itemAction.id, action: outputAction))
                }
            }
            .asEffect()
        }.inject(self.dependencies)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware where StateType: Identifiable, InputAction == OutputAction {
    public func liftToCollection<GlobalAction, GlobalState, CollectionState: MutableCollection>(
        action actionMap: WritableKeyPath<GlobalAction, ElementIDAction<StateType.ID, InputAction>?>,
        stateCollection: KeyPath<GlobalState, CollectionState>
    ) -> EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies> where CollectionState.Element == StateType {
        EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies>.onAction { action, state, context in
            guard let itemAction = action[keyPath: actionMap] else { return .doNothing }
            guard let itemState = state[keyPath: stateCollection].first(where: { $0.id == itemAction.id }) else { return .doNothing }

            let effectForItem = self.onAction(
                itemAction.action,
                itemState,
                .init(
                    dispatcher: context.dispatcher,
                    dependencies: context.dependencies,
                    toCancel: { hashable in .fireAndForget(context.toCancel(hashable)) }
                )
            )

            return effectForItem.map { (effectOutputForItem: EffectOutput<OutputAction>) in
                effectOutputForItem.map { (outputAction: OutputAction) in
                    var newAction = action
                    newAction[keyPath: actionMap] = .init(id: itemAction.id, action: outputAction)
                    return newAction
                }
            }
            .asEffect()
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
        EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies>.onAction { action, state, context in
            guard let itemAction = actionMap(action) else { return .doNothing }
            guard let itemState = stateCollection(state).first(where: { $0.id == itemAction.id }) else { return .doNothing }

            let effectForItem = self.inject(context.dependencies).onAction(
                itemAction.action,
                itemState,
                .init(
                    dispatcher: context.dispatcher,
                    dependencies: context.dependencies,
                    toCancel: { hashable in .fireAndForget(context.toCancel(hashable)) }
                )
            )

            return effectForItem.map { (effectOutputForItem: EffectOutput<ItemOutputActionType>) in
                effectOutputForItem.map { (outputAction: ItemOutputActionType) in
                    outputMap(.init(id: itemAction.id, action: outputAction))
                }
            }
            .asEffect()
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
        EffectMiddleware<GlobalAction, GlobalAction, GlobalState, Dependencies>.onAction { action, state, context in
            guard let itemAction = action[keyPath: actionMap] else { return .doNothing }
            guard let itemState = state[keyPath: stateCollection].first(where: { $0.id == itemAction.id }) else { return .doNothing }

            let effectForItem = self.inject(context.dependencies).onAction(
                itemAction.action,
                itemState,
                .init(
                    dispatcher: context.dispatcher,
                    dependencies: context.dependencies,
                    toCancel: { hashable in .fireAndForget(context.toCancel(hashable)) }
                )
            )

            return effectForItem.map { (effectOutputForItem: EffectOutput<ItemActionType>) in
                effectOutputForItem.map { (outputAction: ItemActionType) in
                    var newAction = action
                    newAction[keyPath: actionMap] = .init(id: itemAction.id, action: outputAction)
                    return newAction
                }
            }
            .asEffect()
        }
    }
}
#endif
