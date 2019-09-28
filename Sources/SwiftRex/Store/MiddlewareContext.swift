/**
 `MiddlewareContext` is a data structure that wraps an `EventHandler` and a `ActionHandler`, offering a way to dispatch events (`EventProtocol`) and trigger actions (`ActionProtocol`). This is usually the way how Middlewares will communicate both, actions and events, to Stores that will re-distribute them through its pipelines.
 */
public struct MiddlewareContext<StateType> {
    /**
     A way for Middlewares to trigger new actions.
     */
    public let actionHandler: ActionHandler

    /**
     A way for Middlewares to dispatch new events.
     */
    public let eventHandler: EventHandler

    /**
     A way for Middlewares to fetch the latest state.
     */
    public let getState: GetState<StateType>

    /**
     A way for Middlewares to fetch the latest state.
     */
    public var next: NextActionHandler

    public init(actionHandler: ActionHandler,
                eventHandler: EventHandler,
                getState: @escaping GetState<StateType>,
                next: @escaping NextActionHandler) {
        self.actionHandler = actionHandler
        self.eventHandler = eventHandler
        self.getState = getState
        self.next = next
    }
}

extension MiddlewareContext {
    public func lift<GlobalStateType>(
        stateMap: @escaping (StateType) -> GlobalStateType) -> MiddlewareContext<GlobalStateType> {
        MiddlewareContext<GlobalStateType>(
            actionHandler: actionHandler,
            eventHandler: eventHandler,
            getState: { () -> GlobalStateType in
                stateMap(self.getState())
            },
            next: { (action: ActionProtocol) -> Void in
                self.next(action)
            }
        )
    }
}
