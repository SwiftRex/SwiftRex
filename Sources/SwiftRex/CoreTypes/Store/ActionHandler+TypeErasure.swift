/// `ActionHandler` defines a protocol for entities able to handle actions - defined by the associated type `ActionType`
///  and `AnyActionHandler` erases this protocol to a generic struct type.
///
/// The only protocol requirement is a function that allows other entities to dispatch actions, so Views (or Presenters,
/// ViewModels) in your UI layer, or even Middlewares can create actions of a certain type and send to your store, that
/// is generalized by this protocol.
public struct AnyActionHandler<ActionType>: ActionHandler {
    private let realHandler: (ActionType, ActionSource) -> Void

    /// Erases the provided `ActionHandler` by using its inner methods from this wrapper
    /// - Parameter realHandler: the concrete `ActionHandler` you're erasing
    public init<A: ActionHandler>(_ realHandler: A) where A.ActionType == ActionType {
        self.init(realHandler.dispatch)
    }

    /// Erases the any type that implements the `dispatch` function to act as a `ActionHandler`
    /// - Parameter realHandler: a function with the same signature of `ActionHandler.dispatch`
    public init(_ realHandler: @escaping (ActionType, ActionSource) -> Void) {
        self.realHandler = realHandler
    }

    /// The function that allows Views, ViewControllers, Presenters to dispatch actions to the store.
    /// Also way for a `Middleware` to trigger their own actions, usually in response to events or async operations.
    /// - Parameters:
    ///   - action: the action to be dispatched
    ///   - dispatcher: information about the action source, containing file/line, function and additional information for debugging and logging
    ///                 purposes
    public func dispatch(_ action: ActionType, from dispatcher: ActionSource) {
        realHandler(action, dispatcher)
    }
}

extension ActionHandler {
    /// Erases the provided `ActionHandler` by using its inner methods from a newly created wrapper of type `AnyActionHandler`
    public func eraseToAnyActionHandler() -> AnyActionHandler<ActionType> {
        AnyActionHandler(self)
    }
}
