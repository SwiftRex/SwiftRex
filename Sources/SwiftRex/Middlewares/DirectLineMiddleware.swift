/**
 The `DirectLineMiddleware` is a useful tool when you have a very simple `EventProtocol` that is also an `ActionProtocol` and no decision has to be made other than forwarding the event as it is to the action queue.

 If the incoming `EventProtocol` is not an `ActionProtocol`, this middleware will act like `BypassMiddleware`, simply forwarding it to the next middleware in the chain.

 For example:
 ```
 enum CounterEvent: EventProtocol, ActionProtocol {
     case increment, decrement
 }
 ```

 When this `CounterEvent` is dispatched to the store, thanks to a `DirectLineMiddleware` it will be forwarded to the `Reducer` without any explicit handling. So you can have a reducer that understands `CounterEvent` and use it to calculate the new `State`.

 This can be really convenient for very simple actions.
 */
public final class DirectLineMiddleware<GlobalState>: Middleware {
    /**
     A `Middleware` is capable of triggering `ActionProtocol` to the `Store`. This property is a nullable `ActionHandler` used for the middleware to trigger the actions. It's gonna be injected by the `Store` or by a parent `Middleware`, so don't worry about it, just use it whenever you need to trigger something.
     */
    public var context: () -> MiddlewareContext<GlobalState>

    /**
     Default initializer for `DirectLineMiddleware`
     */
    public init() {
        self.context = {
            fatalError("No context set for middleware PipelineMiddleware, please be sure to configure your middleware prior to usage")
        }
    }

    /**
     Handles the incoming events. The `DirectLineMiddleware` is a useful tool when you have a very simple `EventProtocol` that is also an `ActionProtocol` and no decision has to be made other than forwarding the event as it is to the action queue.

     If the incoming `EventProtocol` is not an `ActionProtocol`, this middleware will act like `BypassMiddleware`, simply forwarding it to the next middleware in the chain.

     - Parameters:
       - event: the event to be handled
       - getState: a function that can be used to get the current state at any point in time
       - next: the next `Middleware in the chain, probably we want to call this method in some point of our method (not necessarily in the end.
     */
    public func handle(event: EventProtocol, getState: @escaping GetState<GlobalState>, next: @escaping NextEventHandler<GlobalState>) {
        if let action = event as? ActionProtocol {
            context().actionHandler.trigger(action)
        }

        next(event, getState)
    }

    /**
     Handles the incoming actions. The `DirectLineMiddleware` won't do anything with the `ActionProtocol`, simply forwards it to the next middleware in the chain.
     - Parameters:
       - action: the action to be handled
       - getState: a function that can be used to get the current state at any point in time
       - next: the next `Middleware` in the chain, probably we want to call this method in some point of our method (not necessarily in the end. When this is the last middleware in the pipeline, the next function will call the `Reducer` pipeline.
     */
    public func handle(action: ActionProtocol) {
        context().next(action)
    }
}
