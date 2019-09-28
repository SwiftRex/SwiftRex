/**
 The `BypassMiddleware` won't do any operation to either, `EventProtocol` and `ActionProtocol`, it will simply forward them to the next middleware in the chain. It can be useful for Unit Tests or for some compositions.
 */
public final class BypassMiddleware<GlobalState>: Middleware {
    /**
     Every `Middleware` needs some context in order to be able to interface with other middleware and with the store.
     This context includes ways to fetch the most up-to-date state, dispatch new events or call the next middleware in
     the chain.
     */
    public var context: () -> MiddlewareContext<GlobalState>

    /**
     Default initializer for `BypassMiddleware`
     */
    public init() {
        self.context = {
            fatalError("No context set for middleware PipelineMiddleware, please be sure to configure your middleware prior to usage")
        }
    }

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
    public func handle(action: ActionProtocol) {
        context().next(action)
    }
}
