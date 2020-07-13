import Foundation

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct ElementIDAction<ID: Hashable, Action>: Identifiable {
    public let id: ID
    public let action: Action

    public init(id: ID, action: Action) {
        self.id = id
        self.action = action
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Reducer where StateType: Identifiable {
    public func liftToCollection<GlobalAction, GlobalState, CollectionState: MutableCollection>(
        action actionMap: KeyPath<GlobalAction, ElementIDAction<StateType.ID, ActionType>?>,
        stateCollection: WritableKeyPath<GlobalState, CollectionState>
    ) -> Reducer<GlobalAction, GlobalState> where CollectionState.Element == StateType {
        Reducer<GlobalAction, GlobalState> { action, state in
            guard let itemAction = action[keyPath: actionMap] else { return state }
            guard let itemIndex = state[keyPath: stateCollection].firstIndex(where: { $0.id == itemAction.id }) else { return state }
            var state = state
            state[keyPath: stateCollection][itemIndex] = self.reduce(itemAction.action, state[keyPath: stateCollection][itemIndex])
            return state
        }
    }
}
