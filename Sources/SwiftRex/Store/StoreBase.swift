import Foundation

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

 The `StoreBase` implementation also is:
 - an `ActionHandler`: be able to receive and distribute actions of type `ActionProtocol`

 A `StoreBase` uses `Middleware` pipeline and `Reducer` pipeline. It creates a queue of incoming events that is handled to the middleware pipeline, which triggers actions back to the store. These actions are put in a queue that again are handled to the middleware pipeline, usually for logging or analytics purposes. The actions are them forwarded to the `Reducer` pipeline, together with the current state. One by one, the reducers will handle the action and incrementally change a copy of the app state. When this process is done, the store takes the resulting state, sets it as the current state and notifies all subscribers.

 ![Store internals](https://swiftrex.github.io/SwiftRex/markdown/img/StoreInternals.png)
 */
open class StoreBase<ActionType, State> {
    private let middleware: AnyMiddleware<ActionType, State>
    private let reducer: Reducer<ActionType, State>
    private let subject: UnfailableReplayLastSubjectType<State>
    private var _actionHandler: ActionHandler<ActionType>!

    /**
     Required initializer that takes all the expected pipelines

     - Parameters:
       - initialState: when an app is starting, how should be its state struct? Initialize the state and set it before creating the `Store`
       - reducer: a reducer function wrapped in a monoid container of type `Reducer`, able to handle the state of the same type as the `initialState` property. For `reducer` composition, please use the diamond operator (`<>`) and for reducers that understand only a sub-state part, use the `Reducer.lift(_:)` method
       - middleware: a middleware pipeline, that can be any flat middleware or a `ComposedMiddleware`, as long as it's able to handle the state of the same type as the `initialState` property. For `middleware` composition, please use the diamond operator (`<>`) and for middlewares that understand only a sub-state part, use the `Middleware.lift(_:)` method
     */
    public init<M: Middleware>(subject: UnfailableReplayLastSubjectType<State>,
                               reducer: Reducer<ActionType, State>,
                               middleware: M) where M.ActionType == ActionType, M.StateType == State {
        self.subject = subject
        self.reducer = reducer
        self.middleware = AnyMiddleware(middleware)
        self._actionHandler = ActionHandler(onValue: { [unowned self] action in
            DispatchQueue.main.async {
                self.middlewarePipeline(for: action)
            }
        })
        self.middleware.context = { [unowned self] in
            .init(
                actionHandler: self.actionHandler,
                getState: { [unowned self] in self.subject.value() }
            )
        }
    }
}

extension StoreBase: Store {
    public var statePublisher: UnfailablePublisherType<State> { return subject.publisher }
    public var actionHandler: ActionHandler<ActionType> { return _actionHandler }
}

extension StoreBase {
    private func middlewarePipeline(for action: ActionType) {
        middleware.handle(action: action) { [weak self] in
            self?.reduce(action: action)
        }
    }

    private func reduce(action: ActionType) {
        subject.mutate { value in
            value = reducer.reduce(action, value)
        }
    }
}
