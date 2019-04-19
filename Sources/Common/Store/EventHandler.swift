/**
 `EventHandler` defines a protocol for something able to receive and distribute events. Usually a `Store`.
 */
public protocol EventHandler {
    /**
     A way for an `UIViewController` or other classes in the boundaries of the device sensors to communicate and dispatch their events.
     - Parameter event: the event to be managed by this store and handled by its middlewares
     */
    func dispatch(_ event: EventProtocol)
}
