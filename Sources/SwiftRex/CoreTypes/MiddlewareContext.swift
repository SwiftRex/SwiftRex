/**
 `MiddlewareContext` is a data structure that wraps an `EventHandler` and a `ActionHandler`, offering a way to dispatch events (`EventProtocol`) and trigger actions (`ActionProtocol`). This is usually the way how Middlewares will communicate both, actions and events, to Stores that will re-distribute them through its pipelines.
 */
public struct MiddlewareContext<ActionType, StateType> {
    /**
     A way for Middlewares to trigger new actions.
     */
    public let actionHandler: ActionHandler<ActionType>

    /**
     A way for Middlewares to fetch the latest state at any point in time.
     */
    public let getState: GetState<StateType>

    public init(actionHandler: ActionHandler<ActionType>,
                getState: @escaping GetState<StateType>) {
        self.actionHandler = actionHandler
        self.getState = getState
    }
}
