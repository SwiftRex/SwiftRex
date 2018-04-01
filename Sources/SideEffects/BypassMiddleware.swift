public final class BypassMiddleware<GlobalState>: Middleware {
    public weak var actionHandler: ActionHandler?

    public init() { }

    public func handle(event: Event, getState: @escaping GetState<GlobalState>, next: @escaping NextEventHandler<GlobalState>) {
        next(event, getState)
    }

    public func handle(action: Action, getState: @escaping GetState<GlobalState>, next: @escaping NextActionHandler<GlobalState>) {
        next(action, getState)
    }
}
