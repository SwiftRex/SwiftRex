/**
 `ActionHandler` is a data structure that wraps a closuse which represents a way to trigger actions - defined by the type `ActionProtocol`. The entity responsible for receiving and distributing these actions (usually the Store) will offer this closure to the entities that want to trigger new actions (usually the Middlewares).
 */
public protocol ActionHandler {
    associatedtype ActionType

    /**
     The function that allows Views and ViewControllers to dispatch actions to the store.
     Also way for a `Middleware` to trigger their own actions, usually in response to events or async operations.
     */
    func dispatch(_ action: ActionType)
}

// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = ActionType
extension ActionHandler { }
