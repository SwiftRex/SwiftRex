/**
 🏪 `Store` defines a protocol for the state store of an app. It must have an input and an output:
 - an `EventHandler`: that's the store input, so it's able to receive and distribute events of type `EventProtocol`. Being an event handler means that an `UIViewController` can dispatch events to it, such as `.userTappedButtonX`, `.didScrollToPosition(_:)`, `.viewDidLoad` or `queryTextFieldChangedTo(_:)`.
 - a `StateProvider`: that's the store output, so the system can subscribe a store for updates on State. Being a state provider basically means that store is an Observable<T>, where T is the State of your app, so an `UIViewController` can subscribe to state changes and react to them.

 The store will glue all the parts together and its responsibility is being a proxy to the non-Redux world. For that reason, it's correct to say that a `Store` is the single point of contact with `UIKit` and it's a class that you want to inject as a dependency on all the ViewControllers, either as one single dependency or, preferably, a dependency for each of its protocols - `EventHandler` and `StateProvider` -, both eventually pointing to the same instance.

 ![Store and ViewController](https://swiftrex.github.io/SwiftRex/markdown/img/StoreBase.png)

 In its documentation, Apple suggests some communication patterns between the MVC layers. Most important, they say that Controllers should update the Model, who notifies the Controller about changes:

 ![iOS MVC](https://swiftrex.github.io/SwiftRex/markdown/img/CocoaMVC.gif)

 You can think of Store as a very heavy "Model" layer, completely detached from the View and Controller, and where all the business logic stands. At a first sight it may look like transfering the "Massive" problem from a layer to another, but later in this docs it's gonna be clear how the logic will be split and, hopefully, by having specialized middlewares we can even start sharing more code between different apps or different devices such as Apple TV, macOS, iOS, watchOS or backend APIs, thanks to the business decisions being completely off your presentation layer.

 You want only one Store in your app, so either you create a singleton or a public property in a long-life class such as AppDelegate or AppCoordinator. That's crucial for making the store completely detached from the `UIKit` world. Theoretically it should be possible to keep multiple stores - one per module or per `UIViewController` - and keep them in sync through Rx observation, like the "Flux" approach. However, the main goal of SwiftRex is to keep an unified state independent from `UIKit`, therefore it's the recommended approach.

 Specific implementations of a store will require mechanisms to distribute events, mutate the state and notifies subscribers, probably by using `Middleware` and being an `ActionHandler` too, but this is not necessary for the outside world, that only needs the input and output bus of a store.

 Please check (and inherit from) `StoreBase` for a standard implementation.
 */
public protocol Store: StateProvider {
}
