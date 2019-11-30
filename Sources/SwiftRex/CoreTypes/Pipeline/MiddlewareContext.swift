/**
 `MiddlewareContext` is a data structure that provides indirect access to the store, by offering middlewares two important
 features: ability to read the latest state at any point in time through the property `getState: () -> StateType` and the
 ability to dispatch new actions at any point in the through the function `dispatch(_ action: ActionType)`.
 That way, your middleware will be able to perform async tasks or even scheduled task, such as timers, and in some moment
 in the future check the state and/or trigger new actions to the store.
 Every middleware will have a property `context` which it's a closure to access the context, and this property will be
 set by the store when the middleware gets added into the the pipeline.
 */
public struct MiddlewareContext<ActionType, StateType>: ActionHandler {
    private let onAction: (ActionType) -> Void

    /**
     A way for Middlewares to fetch the latest state at any point in time.
     */
    public let getState: GetState<StateType>

    /**
     This initializer will be used by the store in order to inject context into every middleware in the chain. So you
     don't have to worry about it, unless you need to need to write unit tests for your middleware. In that case, there's
     no secret in this context, during initialization you have to provide a closure to dispatch new actions and a closure
     to get latest state, exactly what this context offers for the middleware. You can use in your tests to assert that
     your Middleware has triggered the expected actions when they get certain actions, for example.
     - Parameters:
       - onAction: The store entry-point for incoming actions, usually it will add each action to a serial queue and
                   then forwarded it to the first middleware in the pipeline
       - getState: A way to access the latest global state at any point in time
     */
    public init(onAction: @escaping (ActionType) -> Void, getState: @escaping GetState<StateType>) {
        self.onAction = onAction
        self.getState = getState
    }

    /**
     A way for Middlewares to trigger new actions.
     */
    public func dispatch(_ action: ActionType) {
        onAction(action)
    }
}
