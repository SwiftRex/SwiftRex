/**
 `ActionHandler` is a data structure that wraps a closuse which represents a way to trigger actions - defined by the type `ActionProtocol`. The entity responsible for receiving and distributing these actions (usually the Store) will offer this closure to the entities that want to trigger new actions (usually the Middlewares).
 */
public typealias ActionHandler = UnfailableSubscriberType<ActionProtocol>

extension ActionHandler {
    /**
     A way for a `Middleware` to trigger their actions, usually in response to events or async operations.
     */
    public func trigger(_ action: ActionProtocol) {
        onValue(action)
    }
}
