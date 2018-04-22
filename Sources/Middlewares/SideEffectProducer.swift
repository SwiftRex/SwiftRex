import RxSwift

/**
 🌍 `SideEffectProducer` defines a protocol for implementing a `RxSwift` side-effect producer, that will warms up a cold observation once it's executed. If your producer needs the `EventProtocol` that started the side-effect, you can pass it in the `SideEffectProducer` initializer and save it in a property. Please keep in mind that for every event, a new instance of a `SideEffectProducer` will be created, which means that every execution is completely isolated from each other and if you need to access a shared resource or cancel previous operations you must be careful implementing such things.

 Some Middlewares are shipped with SwiftRex. While you're still welcome to create your own Middlewares from the scratch, some of the stock ones can offer you a shortcut. For RxSwift users we bring a `SideEffectMiddleware` that is a quick way to reuse your existing Observable pipelines. The Middleware requires the implementation of only one method:

 ```
 func sideEffect(for event: Event) -> AnySideEffectProducer<StateType>?
 ```

 Given an event, map it to a Side-Effect producer that handles such event. And what is a Side-Effect producer? It's a protocol with a single method to be implemented:

 ```
 func execute(getState: @escaping GetState<StateType>) -> Observable<Action>
 ```

 Given the current state (that can be checked consistently at any point), return an Observable sequence of `Action`. In your Rx pipeline you can trigger as many side-effects as you want, and every time an Action occurs you can easily notify the observer, that forwards it to the Store.
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
