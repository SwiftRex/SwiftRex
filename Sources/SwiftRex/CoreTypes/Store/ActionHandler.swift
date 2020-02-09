/**
 `ActionHandler` defines a protocol for entities able to handle actions - defined by the associated type `ActionType`.

 The only protocol requirement is a function that allows other entities to dispatch actions, so Views (or Presenters,
 ViewModels) in your UI layer, or even Middlewares can create actions of a certain type and send to your store, that
 is generalized by this protocol.
 */
public protocol ActionHandler {
    associatedtype ActionType

    /// The function that allows Views, ViewControllers, Presenters to dispatch actions to the store.
    /// Also way for a `Middleware` to trigger their own actions, usually in response to events or async operations.
    /// - Parameters:
    ///   - action: the action to be dispatched
    ///   - dispatcher: information about the action source, containing file/line, function and additional information for debugging and logging
    ///                 purposes
    func dispatch(_ action: ActionType, from dispatcher: ActionSource)
}

extension ActionHandler {
    /// The function that allows Views, ViewControllers, Presenters to dispatch actions to the store.
    /// Also way for a `Middleware` to trigger their own actions, usually in response to events or async operations.
    /// - Parameters:
    ///   - action: the action to be dispatched
    ///   - file: File that created and dispatched the action, by default this is the file calling the `dispatch` function
    ///   - function: Function that created and dispatched the action, by default this is the function calling the `dispatch` function
    ///   - line: Line in the file where the action was created and dispatched, by default this is the line from where the `dispatch` function was
    ///           called
    ///   - info: Additional information about the moment where the action was dispatched. This is an optional String that can hold information
    ///           useful for debugging, logging, monitoring or analytics. By default this is nil but you can add any information useful to trace
    ///           the journey of this action.
    public func dispatch(_ action: ActionType, file: String = #file, function: String = #function, line: UInt = #line, info: String? = nil) {
        self.dispatch(action, from: .init(file: file, function: function, line: line, info: info))
    }
}

extension ActionHandler {
    /// Pullback an `ActionHandler` working in a local action context, into a new `ActionHandler` working in a more global action context.
    /// - Parameter transform: a function that allows to go from a global action to a local action
    /// - Returns: a new `ActionHandler` that knows how to handle the new action type
    public func contramap<NewActionType>(_ transform: @escaping (NewActionType) -> ActionType) -> AnyActionHandler<NewActionType> {
        AnyActionHandler { newAction, dispatcher in
            let oldAction = transform(newAction)
            self.dispatch(oldAction, from: dispatcher)
        }
    }
}

// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = ActionType
extension ActionHandler { }
