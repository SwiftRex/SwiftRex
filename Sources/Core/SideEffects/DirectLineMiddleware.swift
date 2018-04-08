public final class DirectLineMiddleware<GlobalState>: Middleware {
    public weak var actionHandler: ActionHandler?

    public init() { }

    public func handle(event: EventProtocol, getState: @escaping GetState<GlobalState>, next: @escaping NextEventHandler<GlobalState>) {
        if let actionHandler = actionHandler, let action = event as? ActionProtocol {
            actionHandler.trigger(action)
        }

        next(event, getState)
    }

    public func handle(action: ActionProtocol, getState: @escaping GetState<GlobalState>, next: @escaping NextActionHandler<GlobalState>) {
        next(action, getState)
    }
}
