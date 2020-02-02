/**
`ActionHandler` defines a protocol for entities able to handle actions - defined by the associated type `ActionType`
 and `AnyActionHandler` erases this protocol to a generic struct type.

The only protocol requirement is a function that allows other entities to dispatch actions, so Views (or Presenters,
ViewModels) in your UI layer, or even Middlewares can create actions of a certain type and send to your store, that
is generalized by this protocol.
*/
public struct AnyActionHandler<ActionType>: ActionHandler {
    private let realHandler: (ActionType) -> Void

    public init<A: ActionHandler>(_ realHandler: A) where A.ActionType == ActionType {
        self.init(realHandler.dispatch)
    }

    public init(_ realHandler: @escaping (ActionType) -> Void) {
        self.realHandler = realHandler
    }

    public func dispatch(_ action: ActionType) {
        realHandler(action)
    }
}

extension ActionHandler {
    public func eraseToAnyActionHandler() -> AnyActionHandler<ActionType> {
        AnyActionHandler(self)
    }
}
