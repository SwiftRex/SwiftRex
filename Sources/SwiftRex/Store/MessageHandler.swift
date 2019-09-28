/**
 `MessageHandler` is a data structure that wraps an `EventHandler` and a `ActionHandler`, offering a way to dispatch events (`EventProtocol`) and trigger actions (`ActionProtocol`). This is usually the way how Middlewares will communicate both, actions and events, to Stores that will re-distribute them through its pipelines.
 */
public struct MiddlewareContext {
    /**
     A way for Middlewares to trigger new actions.
     */
    public let actionHandler: ActionHandler

    /**
     A way for Middlewares to dispatch new events.
     */
    public let eventHandler: EventHandler

    public init(actionHandler: ActionHandler, eventHandler: EventHandler) {
        self.actionHandler = actionHandler
        self.eventHandler = eventHandler
    }
}
