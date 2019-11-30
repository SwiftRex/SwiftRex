/**
 `ActionHandler` defines a protocol for entities able to handle actions - defined by the associated type `ActionType`.

 The only protocol requirement is a function that allows other entities to dispatch actions, so Views (or Presenters,
 ViewModels) in your UI layer, or even Middlewares can create actions of a certain type and send to your store, that
 is generalized by this protocol.
 */
public protocol ActionHandler {
    associatedtype ActionType

    /**
     The function that allows Views, ViewControllers, Presenters to dispatch actions to the store.
     Also way for a `Middleware` to trigger their own actions, usually in response to events or async operations.
     */
    func dispatch(_ action: ActionType)
}

// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = ActionType
extension ActionHandler { }
