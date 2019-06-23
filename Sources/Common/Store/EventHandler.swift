/**
 `EventHandler` is a data structure that wraps a closure which represents a way to dispatch events - defined by the type `EventProtocol`. The entity responsible for receiving and distributing these events (usually the Store) will offer this closure to the entities that want to dispatch new events (usually the ViewControllers/Presenter/ViewModels or even Middlewares).
 */
public typealias EventHandler = UnfailableSubscriberType<EventProtocol>

extension EventHandler {
    /**
     A way for a ViewController, Presenter, ViewModel or Middleware to dispatch new events.
     */
    public func dispatch(_ event: EventProtocol) {
        onValue(event)
    }
}
