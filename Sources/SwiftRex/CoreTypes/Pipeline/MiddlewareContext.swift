/**
 `MiddlewareContext` is a data structure that wraps an `EventHandler` and a `ActionHandler`, offering a way to dispatch events (`EventProtocol`) and trigger actions (`ActionProtocol`). This is usually the way how Middlewares will communicate both, actions and events, to Stores that will re-distribute them through its pipelines.
 */
public struct MiddlewareContext<ActionType, StateType>: ActionHandler {
    private let onAction: (ActionType) -> Void

    /**
     A way for Middlewares to fetch the latest state at any point in time.
     */
    public let getState: GetState<StateType>

    public init(onAction: @escaping (ActionType) -> Void, getState: @escaping GetState<StateType>) {
        self.onAction = onAction
        self.getState = getState
    }

    /**
     A way for Middlewares to trigger new actions.
     */
    public func dispatch(_ action: ActionType) {
        onAction(action)
    }
}
