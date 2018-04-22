import RxSwift

/**
 Defines a protocol for implementing a `RxSwift` side-effect producer, that will warms up a cold observation once it's executed. If your producer needs the `EventProtocol` that started the side-effect, you can pass it in the `SideEffectProducer` initializer and save it in a property. Please keep in mind that for every event, a new instance of a `SideEffectProducer` will be created, which means that every execution is completely isolated from each other and if you need to access a shared resource or cancel previous operations you must be careful implementing such things.
 */
public protocol SideEffectProducer {

    /// State type that is handled by our `SideEffectMiddleware`
    associatedtype StateType

    /**
     Method called when the middleware receives an event that is known by this `SideEffectProducer`, the place for starting the side-effects and returning a sequece of `ActionProtocol` triggered by all stages of it.

     - Parameter getState: a closure to fetch the current state at any moment in time
     - Returns: an `Observable` for all the possible `ActionProtocol` that might be triggered by this producer. This `Observable` must complete or error to free resources.
    */
    func execute(getState: @escaping GetState<StateType>) -> Observable<ActionProtocol>
}

// sourcery: AutoMockable
// sourcery: TypeErase = StateType
extension SideEffectProducer {
}
