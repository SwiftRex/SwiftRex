/**
 `MessageHandler` is a data structure that wraps an `EventHandler` and a `ActionHandler`, offering a way to dispatch events (`EventProtocol`) and trigger actions (`ActionProtocol`). This is usually the way how Middlewares will communicate both, actions and events, to Stores that will re-distribute them through its pipelines.
 */
public struct MessageHandler {
    /**
     A way for Middlewares to trigger new actions.
     */
    let actionHandler: ActionHandler

    /**
     A way for Middlewares to dispatch new events.
     */
    let eventHandler: EventHandler
}
