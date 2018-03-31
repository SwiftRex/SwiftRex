public final class MiddlewareContainer<GlobalState>: Middleware {
    private var middlewares: [AnyMiddleware<GlobalState>] = []

    public func append<M: Middleware>(middleware: M) where M.StateType == GlobalState {
        // Add in reverse order because we reduce from top to bottom and trigger from the last
        middlewares.insert(AnyMiddleware(middleware), at: 0)
    }

    public func handle(event: Event, getState: @escaping () -> GlobalState, next: @escaping (Event, @escaping () -> GlobalState) -> Void) {
        let chain = middlewares.reduce(next) { nextHandler, middleware in
            return { (chainEvent: Event, chainGetState: @escaping () -> GlobalState) in
                middleware.handle(event: chainEvent, getState: chainGetState, next: nextHandler)
            }
        }
        chain(event, getState)
    }

    public func handle(action: Action, getState: @escaping () -> GlobalState, next: @escaping (Action, @escaping () -> GlobalState) -> Void) {
        let chain = middlewares.reduce(next) { nextHandler, middleware in
            return { (chainAction: Action, chainGetState: @escaping () -> GlobalState) in
                middleware.handle(action: chainAction, getState: chainGetState, next: nextHandler)
            }
        }
        chain(action, getState)
    }
}
