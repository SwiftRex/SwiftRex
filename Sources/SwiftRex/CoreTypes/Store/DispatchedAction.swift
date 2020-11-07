import Foundation

/// Wraps an action and the information about its dispatcher. It can be used when reactive pipelines want to enforce that the result is an action
/// while keeping track about the source of that action. For example, certain RxSwift, Combine or ReactiveSwift pipeline want to send actions to the
/// store and because ActionHandler has a function `dispatch(_ action: ActionType, from dispatcher: ActionSource)`, that pipeline should output a
/// `DispatchedAction<Action>` to fulfil everything needed by the ActionHandler to feed that action into the store.
public struct DispatchedAction<Action> {
    /// The action to be handled by the store
    public let action: Action

    /// The source of this action
    public let dispatcher: ActionSource

    /// Init `DispatchedAction` by providing the action and the dispatcher explicitly.
    /// - Parameters:
    ///   - action: The action to be handled by the store
    ///   - dispatcher: The source of this action
    public init(_ action: Action, dispatcher: ActionSource) {
        self.action = action
        self.dispatcher = dispatcher
    }

    /// Init `DispatchedAction` by providing the action and the components pointing to the source of this action, such as file, function and line.
    /// Those parameters are optional and fallback to Swift precompiled defaults `#file`, `#function` and `#line`.
    /// - Parameters:
    ///   - action: The action to be handled by the store
    ///   - file: File that dispatched the action, defaults to `#file`
    ///   - function: Function that dispatched the action, defaults to `#function`
    ///   - line: Line that dispatched the action, defaults to `#line`
    ///   - info: Optional extra information about the dispatcher. Useful to aggregate more data about the journey of an action for logging purposes.
    public init(_ action: Action, file: String = #file, function: String = #function, line: UInt = #line, info: String? = nil) {
        self.init(
            action,
            dispatcher: ActionSource(file: file, function: function, line: line, info: info)
        )
    }
}

extension DispatchedAction {
    /// Transforms an action while keeping the dispatcher intact
    /// - Parameter transform: Function that will transform an action into another
    /// - Returns: another `DispatchedAction` generic over the new action type. The dispatcher is kept as the original action.
    public func map<NewAction>(_ transform: (Action) -> NewAction) -> DispatchedAction<NewAction> {
        DispatchedAction<NewAction>(transform(action), dispatcher: dispatcher)
    }
}
