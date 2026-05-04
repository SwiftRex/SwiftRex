/// An action paired with the call-site that dispatched it.
///
/// Middleware receives `DispatchedAction<InputAction>` on the incoming side, giving access to both
/// the action and its origin for logging, tracing, and analytics. On the outgoing side middlewares
/// return raw `Action` values; the framework wraps them using the source captured at the `Effect`
/// factory call site.
public struct DispatchedAction<Action>: Sendable where Action: Sendable {
    public let action: Action
    public let dispatcher: ActionSource

    public init(_ action: Action, dispatcher: ActionSource) {
        self.action = action
        self.dispatcher = dispatcher
    }
}

extension DispatchedAction {
    public func map<B>(_ transform: (Action) -> B) -> DispatchedAction<B> {
        DispatchedAction<B>(transform(action), dispatcher: dispatcher)
    }

    public func compactMap<B>(_ transform: (Action) -> B?) -> DispatchedAction<B>? {
        transform(action).map { DispatchedAction<B>($0, dispatcher: dispatcher) }
    }
}
