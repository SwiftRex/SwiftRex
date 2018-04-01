public final class ComposedMiddleware<GlobalState>: Middleware {
    private var middlewares: [AnyMiddleware<GlobalState>] = []

    public init() { }

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

    public func handle(event: Event, getState: @escaping GetState<GlobalState>, next: @escaping NextEventHandler<GlobalState>) {
        let chain = middlewares.reduce(next) { nextHandler, middleware in
            return { (chainEvent: Event, chainGetState: @escaping GetState<GlobalState>) in
                middleware.handle(event: chainEvent, getState: chainGetState, next: nextHandler)
            }
        }
        chain(event, getState)
    }

    public func handle(action: Action, getState: @escaping GetState<GlobalState>, next: @escaping NextActionHandler<GlobalState>) {
        let chain = middlewares.reduce(next) { nextHandler, middleware in
            return { (chainAction: Action, chainGetState: @escaping GetState<GlobalState>) in
                middleware.handle(action: chainAction, getState: chainGetState, next: nextHandler)
            }
        }
        chain(action, getState)
    }
}

public func >>> <M1: Middleware, M2: Middleware> (lhs: M1, rhs: M2) -> ComposedMiddleware<M1.StateType> where M1.StateType == M2.StateType {

    let container = lhs as? ComposedMiddleware<M1.StateType> ?? {
        let newContainer: ComposedMiddleware<M1.StateType> = .init()
        newContainer.append(middleware: lhs)
        return newContainer
        }()

    container.append(middleware: rhs)
    return container
}
