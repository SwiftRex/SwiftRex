/**
 `ActionHandler` defines a protocol for something able to receive and distribute actions. A `Store` doesn't need to be `ActionHandler`, because this would expose the inner working of it. The `StoreBase`, on the other hand, is a default implementation of a `Store` that happens to use middlewares and `ActionHandler`.
 */
public protocol ActionHandler: class {
    /**
     A way for a `Middleware` to trigger their actions, usually in response to events or async operations.
     - Parameter action: the action to be managed by this store and handled by its middlewares and reducers
     */
    func trigger(_ action: ActionProtocol)
}

// sourcery: AutoMockable
extension ActionHandler { }
