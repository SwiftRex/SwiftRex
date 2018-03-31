public final class DirectLineMiddleware<GlobalState>: Middleware {
    public weak var actionHandler: ActionHandler?

    public func handle(event: Event, getState: @escaping GetState<GlobalState>, next: @escaping NextEventHandler<GlobalState>) {
        if let actionHandler = actionHandler, let action = event as? Action {
            actionHandler.trigger(action)
        }

        next(event, getState)
    }

    public func handle(action: Action, getState: @escaping GetState<GlobalState>, next: @escaping NextActionHandler<GlobalState>) {
        next(action, getState)
    }
}
