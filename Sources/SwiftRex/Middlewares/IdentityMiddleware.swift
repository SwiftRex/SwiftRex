/**
 The `IdentityMiddleware` won't do any operation, simply bypass actions through. It's meant to provide identity axiom
 to middleware type to allow its conformance to monoid algebra. It will simply forward actions to the next middleware
 in the chain or to the reducers. It can be useful for Unit Tests or for some compositions.
 */
public final class IdentityMiddleware<ActionType, GlobalState>: Middleware {
    /**
     Every `Middleware` needs some context in order to be able to interface with other middleware and with the store.
     This context includes ways to fetch the most up-to-date state, dispatch new events or call the next middleware in
     the chain.
     */
    public var context: () -> MiddlewareContext<ActionType, GlobalState>

    /**
     Default initializer for `IdentityMiddleware`
     */
    public init() {
        self.context = {
            fatalError("No context set for middleware PipelineMiddleware, please be sure to configure your middleware prior to usage")
        }
    }
}
