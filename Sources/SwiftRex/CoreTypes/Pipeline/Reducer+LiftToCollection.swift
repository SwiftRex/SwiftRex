import Foundation

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Reducer where StateType: Identifiable {
    public func liftToCollection<GlobalAction, GlobalState, CollectionState: MutableCollection>(
        action actionMap: KeyPath<GlobalAction, ElementIDAction<StateType.ID, ActionType>?>,
        stateCollection: WritableKeyPath<GlobalState, CollectionState>
    ) -> Reducer<GlobalAction, GlobalState> where CollectionState.Element == StateType {
        Reducer<GlobalAction, GlobalState>.reduce { action, state in
            guard let itemAction = action[keyPath: actionMap],
                  let itemIndex = state[keyPath: stateCollection].firstIndex(where: { $0.id == itemAction.id })
            else { return }

            self.reduce(itemAction.action, &state[keyPath: stateCollection][itemIndex])
        }
    }
}

extension Reducer {
    public func liftToCollection<GlobalAction, GlobalState, CollectionState: MutableCollection, ID: Hashable>(
        action actionMap: KeyPath<GlobalAction, ElementIDAction<ID, ActionType>?>,
        stateCollection: WritableKeyPath<GlobalState, CollectionState>,
        identifier: KeyPath<StateType, ID>
    ) -> Reducer<GlobalAction, GlobalState> where CollectionState.Element == StateType {
        Reducer<GlobalAction, GlobalState>.reduce { action, state in
            guard let itemAction = action[keyPath: actionMap],
                  let itemIndex = state[keyPath: stateCollection].firstIndex(where: { $0[keyPath: identifier] == itemAction.id })
            else { return }

             self.reduce(itemAction.action, &state[keyPath: stateCollection][itemIndex])
        }
    }
}

extension Reducer {
    public func liftToCollection<GlobalAction, GlobalState, CollectionState: MutableCollection>(
        action actionMap: KeyPath<GlobalAction, ElementIndexAction<CollectionState.Index, ActionType>?>,
        stateCollection: WritableKeyPath<GlobalState, CollectionState>
    ) -> Reducer<GlobalAction, GlobalState> where CollectionState.Element == StateType {
        Reducer<GlobalAction, GlobalState>.reduce { action, state in
            guard let itemAction = action[keyPath: actionMap],
                  state[keyPath: stateCollection].inBounds(itemAction.index)
            else { return }

            self.reduce(itemAction.action, &state[keyPath: stateCollection][itemAction.index])
        }
    }
}
