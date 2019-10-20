/**
 The `IdentityMiddleware` won't do any operation, simply bypass actions through. It's meant to provide identity axiom
 to middleware type to allow its conformance to monoid algebra. It will simply forward actions to the next middleware
 in the chain or to the reducers. It can be useful for Unit Tests or for some compositions.
 */
public final class IdentityMiddleware<InputActionType, OutputActionType, GlobalState>: Middleware {
    /**
     Every `Middleware` needs some context in order to be able to interface with other middleware and with the store.
     This context includes ways to fetch the most up-to-date state, dispatch new events or call the next middleware in
     the chain.
     */
    public var context: () -> MiddlewareContext<OutputActionType, GlobalState>

    /**
     Default initializer for `IdentityMiddleware`
     */
    public init() {
        self.context = {
            fatalError("No context set for middleware PipelineMiddleware, please be sure to configure your middleware prior to usage")
        }
    }

    /**
     Handles the incoming actions and may or not start async tasks, check the latest state at any point or dispatch
     additional actions. This is also a good place for analytics, tracking, logging and telemetry.
     In this empty implementation, will do nothing but call next delegate.
     - Parameters:
       - action: the action to be handled
       - next: opportunity to call the next middleware in the chain and, eventually, the reducer pipeline. Call it
               only once, not more or less than once. Call it from the same thread and runloop where the handle function
               is executed, never from a completion handler or dispatch queue block. In case you don't need to compare
               state before and after it's changed from the reducers, please consider to add a `defer` block with `next()`
               on it, at the beginning of `handle` function.
     */
    public func handle(action: InputActionType, next: @escaping Next) {
        next()
    }
}
