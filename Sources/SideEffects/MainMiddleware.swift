public final class MiddlewareContainer<GlobalState>: Middleware {
    private var middlewares: [AnyMiddleware<GlobalState>] = []

    public weak var actionHandler: ActionHandler? {
        didSet {
            middlewares.forEach { $0.actionHandler = actionHandler }
        }
    }

    public func append<M: Middleware>(middleware: M) where M.StateType == GlobalState {
        // Add in reverse order because we reduce from top to bottom and trigger from the last
        middleware.actionHandler = middleware.actionHandler ?? actionHandler
        middlewares.insert(AnyMiddleware(middleware), at: 0)
    }

    public func handle(event: Event, getState: @escaping GetState<GlobalState>, next: @escaping (Event, @escaping GetState<GlobalState>) -> Void) {
        let chain = middlewares.reduce(next) { nextHandler, middleware in
            return { (chainEvent: Event, chainGetState: @escaping GetState<GlobalState>) in
                middleware.handle(event: chainEvent, getState: chainGetState, next: nextHandler)
            }
        }
        chain(event, getState)
    }

    public func handle(action: Action, getState: @escaping GetState<GlobalState>, next: @escaping (Action, @escaping GetState<GlobalState>) -> Void) {
        let chain = middlewares.reduce(next) { nextHandler, middleware in
            return { (chainAction: Action, chainGetState: @escaping GetState<GlobalState>) in
                middleware.handle(action: chainAction, getState: chainGetState, next: nextHandler)
            }
        }
        chain(action, getState)
    }
}
