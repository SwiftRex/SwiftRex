import Foundation
/**
 🏪 `ReduxStoreBase` is a base class that can be used to create the main store of an app, using the redux pattern.

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

 This type of store will glue all the parts together and its responsibility is owning the main state, which means the
 only source-of-truth an app can have, besides of coordinating the sequence of operations that will be triggered once a
 new action arrives from views or middlewares. It's highly recommended that your app should have only a single instance
 of this class and, directly or indirectly, all the other parts of your app will react to the state notifications sent
 by this instance.

 That means that other types of store can act as a proxy to this one, but none of them should hold any state. For more
 information on that please check `StoreProjection`.

 ![Store, StoreProjection and View](https://swiftrex.github.io/SwiftRex/markdown/img/StoreProjectionDiagram.png)

 You can think of Store as a very heavy "Model" layer, completely detached from the Views, Controllers, Presenters etc.,
 and where all the business logic stands. At a first sight it may look like transferring the "Massive" problem from a
 layer to another, but the store actually won't have any of this logic, only coordinate the multiple entities that do
 that. These entities are `Middleware` and `Reducer`, and you can learn more about them in their own documentation.

 The `ReduxStoreBase` has a pipeline of middlewares and reducers. Upon an action arrival, which first is bottlenecked
 into a serial queue, every middleware will have the chance to handle the action, and trigger side-effects in response.
 These middlewares also have read-only access to the state at any point, and can dispatch new actions to the beginning
 of the process at any point. Once all middlewares were informed about the action, now your reducers will have the
 chance to act. The reducers can't trigger side-effects or do any async operation, all they do is calculating a new
 version of the app state from the old version of the app state plus the action. One-by-one the reducers will shape the
 new state, accumulatively. When they are done, the store publishes the final state as the new one, and notifies all the
 subscribers.

 ![Store internals](https://swiftrex.github.io/SwiftRex/markdown/img/StoreInternals.png)

 ```
                   ┌────────────────────────────────────────┐
                   │                                        │
                   │    SwiftUI View / UIViewController     │
                   │                                        │
                   └────┬───────────────────────────────────┘
                        │                            ▲
                        │                            │
                        │ action        notification
            ┌─────────┐ │                            │
            │         ▼ │                       ─ ─ ─ ─ ─ ─
            │      ┏━━━━│━━━━━━━━━━━━━━━━━━━━━━┫   State   ┣┓
    new actions    ┃    │            Store       Publisher  ┃░
  from middleware  ┃    ▼                      └ ─ ─ ┬ ─ ─ ┘┃░
            │      ┃ ┌───────────────────┐                  ┃░
            │      ┃ │    Middlewares    │           │      ┃░
            └────────┤┌───┐  ┌───┐  ┌───┐│                  ┃░
                   ┃ ││ 1 │─▶│ 2 │─▶│ 3 ││◀─         │      ┃░
                   ┃ │└───┘  └───┘  └───┘│  │               ┃░
                   ┃ └────────────────┬──┘      ┌────┴────┐ ┃░
                   ┃                  │     │   │         │ ┃░
                   ┃    ┌─────────────┘      ─ ─│  State  │ ┃░
                   ┃    │ ┌─────────────────────│         │ ┃░
                   ┃    ▼ ▼                     └────▲────┘ ┃░
                   ┃ ┌───────────────────┐           ║      ┃░
                   ┃ │     Reducers      │           ║      ┃░
                   ┃ │┌───┐  ┌───┐  ┌───┐│           ║      ┃░
                   ┃ ││ 1 │─▶│ 2 │─▶│ 3 │╠═══════════╝      ┃░
                   ┃ │└───┘  └───┘  └───┘│    state         ┃░
                   ┃ └───────────────────┘   mutation       ┃░
                   ┃                                        ┃░
                   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛░
                    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
 ```
 
 By using this architecture, your model gets completely detached from the `UIKit`/`SwiftUI` world. And your UI gets
 completely independent from side-effects, state mutations, threading, ownership, logic, logs, analytics and everything
 other than UI. No more dependency injection for your views, they only need to know about the store (the main one or
 a derived view store).
 */
open class ReduxStoreBase<ActionType, StateType>: ReduxStoreProtocol {
    private let subject: UnfailableReplayLastSubjectType<StateType>

    /// Pipeline to execute upon action arrival, containing all middlewares and reducers
    public let pipeline: ReduxPipelineWrapper<AnyMiddleware<ActionType, ActionType, StateType>>

    /// State publisher which can be subscribed in order to be notified on every mutation
    public var statePublisher: UnfailablePublisherType<StateType> { subject.publisher }

    /**
     Required initializer that configures the action handler pipeline and the state storage

     - Parameters:
       - subject: a reactive subject type that replays the last value, never fails and works on `StateType` elements. It
                  should contain the initial state already.
       - reducer: a reducer function wrapped in a monoid container of type `Reducer`, able to handle the state of the
                  type `StateType` and actions of type `ActionType`. For `reducer` composition, please use the diamond
                  operator (`<>`) and for reducers that understand only a sub-state part, use the `lift` functions to
                  elevate them to the same global state and global action type.
       - middleware: a middleware pipeline, that can be any flat middleware or a `ComposedMiddleware`, as long as it's
                     able to handle the state of type `StateType` and actions of type `ActionType`. For `middleware`
                     composition, please use the diamond operator (`<>`) and for middlewares that understand only a
                     sub-state part, use the `lift` functions to elevate them to the same global state and global action
                     type.
     */
    public init<M: Middleware>(
        subject: UnfailableReplayLastSubjectType<StateType>,
        reducer: Reducer<ActionType, StateType>,
        middleware: M,
        emitsValue: ShouldEmitValue<StateType> = .always
    ) where M.InputActionType == ActionType, M.InputActionType == M.OutputActionType, M.StateType == StateType {
        self.subject = subject
        self.pipeline = .init(state: subject, reducer: reducer, middleware: AnyMiddleware(middleware), emitsValue: emitsValue)
    }
}
