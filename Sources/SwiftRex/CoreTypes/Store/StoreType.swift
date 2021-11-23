/// A protocol that defines the two expected roles of a "Store": receive/distribute actions (``ActionHandler``); and publish changes of the the
/// current app state (``StateProvider``) to possible subscribers. It can be a real store (such as ``ReduxStoreBase``) or just a "proxy" that acts on
/// behalf of a real store, for example, in the case of ``StoreProjection``.
public protocol StoreType: StateProvider, ActionHandler { }

extension StoreType {
    /// Create another ``StoreType`` that handles a different type of Action. The original store will be used behind the scenes, by only the provided
    /// "transform" closure whenever an action arrives.
    ///
    /// - Parameters:
    ///   - transform: a closure that will be executed every time an action arrives at the proxy ``StoreType``, so we can map it into the expected
    ///                action type of the original ``StoreType``.
    /// - Returns: an ``AnyStoreType`` with same `Statetype` but different `ActionType` than the original store.
    public func contramapAction<NewActionType>(_ transform: @escaping (NewActionType) -> ActionType)
    -> AnyStoreType<NewActionType, StateType> {
        AnyStoreType(
            action: { dispatchedAction in
                let oldAction = transform(dispatchedAction.action)
                self.dispatch(oldAction, from: dispatchedAction.dispatcher)
            },
            state: self.statePublisher
        )
    }

    /// Create another ``StoreType`` that handles a different type of State. The original store will be used behind the scenes, by only applying
    /// the provided "transform" closure whenever the state changes in the original store.
    ///
    /// - Parameters:
    ///   - transform: a closure that will be executed every time the state changes in the original store, so we can map it into the state type
    ///                expected by the subscribers of the proxy ``StoreType``.
    /// - Returns: an ``AnyStoreType`` with same `ActionType` but different `StateType` than the original store.
    public func mapState<NewStateType>(_ transform: @escaping (StateType) -> NewStateType)
    -> AnyStoreType<ActionType, NewStateType> {
        AnyStoreType(
            action: self.dispatch,
            state: self.statePublisher.map(transform)
        )
    }
}

// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = StateType
// sourcery: AutoMockableGeneric = ActionType
extension StoreType { }
