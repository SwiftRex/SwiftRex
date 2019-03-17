/**
 The `BypassMiddleware` won't do any operation to either, `EventProtocol` and `ActionProtocol`, it will simply forward them to the next middleware in the chain. It can be useful for Unit Tests or for some compositions.
 */
public final class BypassMiddleware<GlobalState>: Middleware {

    /**
     A `Middleware` is capable of triggering `ActionProtocol` to the `Store`. This property is a nullable `ActionHandler` used for the middleware to trigger the actions. It's gonna be injected by the `Store` or by a parent `Middleware`, so don't worry about it, just use it whenever you need to trigger something.
     */
    public weak var actionHandler: ActionHandler?

    /**
     Default initializer for `BypassMiddleware`
     */
    public init() { }

    /**
     Handles the incoming events. The `BypassMiddleware` won't do anything with the `EventProtocol`, simply forwards it to the next middleware in the chain.

     - Parameters:
       - event: the event to be handled
       - getState: a function that can be used to get the current state at any point in time
       - next: the next `Middleware in the chain, probably we want to call this method in some point of our method (not necessarily in the end.
     */
    public func handle(event: EventProtocol, getState: @escaping GetState<GlobalState>, next: @escaping NextEventHandler<GlobalState>) {
        next(event, getState)
    }

    /**
     Handles the incoming actions. The `BypassMiddleware` won't do anything with the `ActionProtocol`, simply forwards it to the next middleware in the chain.
     - Parameters:
       - action: the action to be handled
       - getState: a function that can be used to get the current state at any point in time
       - next: the next `Middleware` in the chain, probably we want to call this method in some point of our method (not necessarily in the end. When this is the last middleware in the pipeline, the next function will call the `Reducer` pipeline.
     */
    public func handle(action: ActionProtocol, getState: @escaping GetState<GlobalState>, next: @escaping NextActionHandler<GlobalState>) {
        next(action, getState)
    }
}
