/**
 🏪 `StoreType` defines a protocol for a state store.

 A store should have a single input and a single output, being the input the method to handle actions dispatched by the
 counterparts, and the output the state that can be observed by them. For that reason, a `StoreType` protocol is nothing
 but a composition of two other protocols: `ActionHandler` and `StateProvider`:

 - as `ActionHandler`, which represents the store input, it's gonna be able to receive and distribute action of a
 generic type `ActionType`. Being an action handler means that an `UIViewController` or SwiftUI `View` can dispatch
 actions to it, such as `.saveButtonTapped`, `.didScrollToPosition(y)`, `.viewDidLoad` or `.queryTextFieldChanged(text)`.
 - as `StateProvider`, which represents the store output, it's gonna be able to offer to the system a way to subscribe
 for updates on State. Being a state provider basically means that a store has a `statePublisher` that is either a
 `Observable<StateType>`, `SignalProducer<StateType, Never>` or `Publisher<StateType, Never>` depending on the reactive
 framework of your choice, so an `UIViewController` can subscribe to state changes and react to them, or a SwiftUI View
 can use it as a `ObservedObject`.

 Not necessarily a store implementation means that this entity holds the source-of-truth of an app. Every app should
 have a single and centralized store, where the whole state is held. But Views and ViewControllers do not necessarily
 need to access this main Store directly, they could, instead, access some "proxy" store that intermediates the actions (inputs) and state change notifications (outputs), without actually holding the truth. For more information
 on that please check `StoreProjection`, and compare it to `ReduxStoreBase`.

 In summary, it's recommended to have one and only store `ReduxStoreBase` in your app, holding the one and only one
 source-of-truth, but at the same time having several `StoreProjection` instances mapping the whole state and whole set of
 possible actions from and to view state and events relevant to the specific view you implement.

 ![Store, StoreProjection and View](https://swiftrex.github.io/SwiftRex/markdown/img/StoreProjectionDiagram.png)
 */
public protocol StoreType: StateProvider, ActionHandler {
}

// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = ActionType
// sourcery: AutoMockableGeneric = StateType
extension StoreType { }
