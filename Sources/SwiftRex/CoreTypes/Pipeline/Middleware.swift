/// ⛓ `Middleware` is a plugin, or a composition of several plugins, that are assigned to the `ReduxStoreProtocol` pipeline in order to handle each
/// action received (`InputActionType`), to execute side-effects in response, and eventually dispatch more actions (`OutputActionType`) in the process.
/// This happens before the `Reducer` to do its job.
///
/// We can think of a Middleware as an object that transforms actions into sync or async tasks and create more actions as these side-effects complete,
/// also being able to check the current state at any point.
///
/// An action is a lightweight structure, typically an enum, that is dispatched into the `ActionHandler` (usually a `StoreProtocol`).
/// A Store like `ReduxStoreProtocol` enqueues a new action that arrives and submits it to a pipeline of middlewares. So, in other words, a `Middleware`
/// is class that handles actions, and has the power to dispatch more actions to the `ActionHandler` chain. The `Middleware` can also simply ignore the
/// action, or it can execute side-effects in response, such as logging into file or over the network, or execute http requests, for example. In case of
/// those async tasks, when they complete the middleware can dispatch new actions containing a payload with the response (a JSON file, an array of
/// movies, credentials, etc). Other middlewares will handle that, or maybe even the same middleware in a future RunLoop, or perhaps some `Reducer`, as
/// reducers pipeline is at the end of every middleware pipeline.
///
/// Middlewares can schedule a callback to be executed after the reducer pipeline is done mutating the global state. At that point, the middleware
/// will have access to the new state, and in case it cached the old state it can compare them, log, audit, perform analytics tracking, telemetry or
/// state sync with external devices, such as Apple Watches. Remote Debugging over the network is also a great use of a Middleware.
///
/// Every action dispatched also comes with its action source, which is the primary dispatcher of that action. Middlewares can access the file, line,
/// function and additional information about the entity responsible for creating and dispatching that action, which is a very powerful debugging
/// information that can help developers to trace how the information flows through the app.
///
/// Because the `Middleware` receive all actions and accesses the state of the app at any point, anything can be done from these small and reusable
/// boxes. For example, the same `CoreLocation` middleware could be used from an iOS app, its extensions, the Apple Watch extension or even different
/// apps, as long as they share some sub-state struct.
///
/// Some suggestions of middlewares:
///
/// - Run Timers, pooling some external resource or updating some local state at a constant time
/// - Subscribe for `CoreData`, `Realm`, `Firebase Realtime Database` or equivalent database changes
/// - Be a `CoreLocation` delegate, checking for significant location changes or beacon ranges and triggering actions to update the state
/// - Be a `HealthKit` delegate to track activities, or even combining that with `CoreLocation` observation in order to track the activity route
/// - Logger, Telemetry, Auditing, Analytics tracker, Crash report breadcrumbs
/// - Monitoring or debugging tools, like external apps to monitor the state and actions remotely from a different device
/// - `WatchConnectivity` sync, keep iOS and watchOS state in sync
/// - API calls and other "cold observables"
/// - Network Reachability
/// - Navigation through the app (Redux Coordinator pattern)
/// - `CoreBluetooth` central or peripheral manager
/// - `CoreNFC` manager and delegate
/// - `NotificationCenter` and other delegates
/// - WebSocket, TCP Socket, Multipeer and many other connectivity protocols
/// - `RxSwift` observables, `ReactiveSwift` signal producers, `Combine` publishers
/// - Observation of traits changes, device rotation, language/locale, dark mode, dynamic fonts, background/foreground state
/// - Any side-effect, I/O, networking, sensors, third-party libraries that you want to abstract
///
/// ```
///                   ┌─────┐                                                                                        ┌─────┐
///                   │     │     handle   ┌──────────┐ request      ┌ ─ ─ ─ ─  response     ┌──────────┐ dispatch   │     │
///                   │     │   ┌─────────▶│Middleware├─────────────▶ External│─────────────▶│Middleware│───────────▶│Store│─ ─ ▶ ...
///                   │     │   │ Action   │ Pipeline │ side-effects │ World    side-effects │ callback │ New Action │     │
///                   │     │   │          └──────────┘               ─ ─ ─ ─ ┘              └──────────┘            └─────┘
/// ┌──────┐ dispatch │     │   │                ▲
/// │Button│─────────▶│Store│──▶│                └───afterReducer─────┐                   ┌────────┐
/// └──────┘ Action   │     │   │                                     │                ┌─▶│ View 1 │
///                   │     │   │                                  ┌─────┐             │  └────────┘
///                   │     │   │ reduce   ┌──────────┐            │     │ onNext      │  ┌────────┐
///                   │     │   └─────────▶│ Reducer  ├───────────▶│Store│────────────▶├─▶│ View 2 │
///                   │     │     Action   │ Pipeline │ New state  │     │ New state   │  └────────┘
///                   └─────┘     +        └──────────┘            └─────┘             │  ┌────────┐
///                               State                                                └─▶│ View 3 │
///                                                                                       └────────┘
/// ```
///
/// Middleware protocol is generic over 3 associated types:
/// 
/// #### InputActionType:
/// The Action type that this `Middleware` knows how to handle, so the store will forward actions of this type to this middleware.
/// Thanks to optics, this action can be a sub-action lifted to a global action type in order to compose with other middlewares acting on the global action of an app. Please check `lift(inputActionMap:outputActionMap:stateMap:)` for more details.
/// 
/// #### OutputActionType:
/// The Action type that this `Middleware` will eventually trigger back to the store in response of side-effects. This can be the same as `InputActionType` or different, in case you want to separate your enum in requests and responses.
/// Thanks to optics, this action can be a sub-action lifted to a global action type in order to compose with other middlewares acting on the global action of an app. Please check `lift(inputActionMap:outputActionMap:stateMap:)` for more details.
/// 
/// #### StateType:
/// The State part that this `Middleware` needs to read in order to make decisions. This middleware will be able to read the most up-to-date `StateType` from the store at any point in time, but it can never write or make changes to it. In some cases, middleware don't need reading the whole global state, so we can decide to allow only a sub-state, or maybe this middleware doesn't need to read any state, so the `StateType`can safely be set to `Void`.
/// Thanks to lenses, this state can be a sub-state lifted to a global state in order to compose with other middlewares acting on the global state of an app. Please check `lift(inputActionMap:outputActionMap:stateMap:)` for more details.
/// 
/// When implementing your Middleware, all you have to do is to handle the incoming actions:
/// 
/// 
///  When implementing your Middleware, all you have to do is to handle the incoming actions:
/// ```
/// class LoggerMiddleware: Middleware {
///     typealias InputActionType = AppGlobalAction // It wants to receive all possible app actions
///     typealias OutputActionType = Never          // No action is generated from this Middleware
///     typealias StateType = AppGlobalState        // It wants to read the whole app state
/// 
///     var getState: GetState<AppGlobalState>!
/// 
///     func receiveContext(getState: @escaping GetState<AppGlobalState>, output: AnyActionHandler<Never>) {
///         self.getState = getState
///     }
/// 
///     func handle(action: AppGlobalAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
///         let stateBefore: AppGlobalState = getState()
///         let dateBefore = Date()
/// 
///         afterReducer = .do {
///             let stateAfter = self.getState()
///             let dateAfter = Date()
///             let source = "\(dispatcher.file):\(dispatcher.line) - \(dispatcher.function) | \(dispatcher.info ?? "")"
/// 
///             Logger.log(action: action, from: source, before: stateBefore, after: stateAfter, dateBefore: dateBefore, dateAfter: dateAfter)
///         }
///     }
/// }
/// 
/// class FavoritesAPIMiddleware: Middleware {
///     typealias InputActionType = FavoritesAction  // It wants to receive only actions related to Favorites
///     typealias OutputActionType = FavoritesAction // It wants to also dispatch actions related to Favorites
///     typealias StateType = FavoritesModel         // It wants to read the app state that manages favorites
/// 
///     var getState: GetState<FavoritesModel>!
///     var output: AnyActionHandler<FavoritesAction>!
/// 
///     func receiveContext(getState: @escaping GetState<FavoritesModel>, output: AnyActionHandler<FavoritesAction>) {
///         self.getState = getState
///         self.output = output
///     }
/// 
///     func handle(action: FavoritesAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
///         guard let .toggleFavorite(movieId) = action else { return }
/// 
///         let favoritesList = getState()
///         let makeFavorite = !favoritesList.contains(where: { $0.id == movieId })
/// 
///         API.changeFavorite(id: movieId, makeFavorite: makeFavorite) (completion: { result in
///             switch result {
///             case let .success(value):
///                 self.output.dispatch(.changedFavorite(movieId, isFavorite: true), info: "API.changeFavorite callback")
///             case let .failure(error):
///                 self.output.dispatch(.changedFavoriteHasFailed(movieId, isFavorite: false, error: error), info: "API.changeFavorite callback")
///             }
///         })
///     }
/// }
/// ```
///
/// ![SwiftUI Side-Effects](https://swiftrex.github.io/SwiftRex/markdown/img/wwdc2019-226-02.jpg)
///
public protocol Middleware {
    /**
     The Action type that this `Middleware` knows how to handle, so the store will forward actions of this type to this middleware.
     Thanks to optics, this action can be a sub-action lifted to a global action type in order to compose with other middlewares acting on the global
     action of an app. Please check `lift(inputActionMap:outputActionMap:stateMap:)` for more details.
     */
    associatedtype InputActionType

    /**
     The Action type that this `Middleware` will eventually trigger back to the store in response of side-effects. This can be the same as
     `InputActionType` or different, in case you want to separate your enum in requests and responses.
     Thanks to optics, this action can be a sub-action lifted to a global action type in order to compose with other middlewares acting on the global
     action of an app. Please check `lift(inputActionMap:outputActionMap:stateMap:)` for more details.
     */
    associatedtype OutputActionType

    /**
     The State part that this `Middleware` needs to read in order to make decisions. This middleware will be able to read the most up-to-date
     `StateType` from the store at any point in time, but it can never write or make changes to it. In some cases, middleware don't need reading the
     whole global state, so we can decide to allow only a sub-state, or maybe this middleware doesn't need to read any state, so the `StateType`can
     safely be set to `Void`.
     Thanks to lenses, this state can be a sub-state lifted to a global state in order to compose with other middlewares acting on the global state
     of an app. Please check `lift(inputActionMap:outputActionMap:stateMap:)` for more details.
     */
    associatedtype StateType

    /**
     Middleware setup. This function will be called before actions are handled to the middleware, so you can configure your middleware with the given
     parameters. You can hold any of them if you plan to read the state or dispatch new actions.
     You can initialize and start timers or async tasks in here or in the `handle(action:next)` function, but never before this function is called,
     otherwise the middleware would not yet be running from a store.
     Because no actions are delivered to this middleware before the `receiveContext(getState:output:)` is called, you can safely keep implicit
     unwrapped versions of `getState` and `output` as properties of your concrete middleware, and set them from the arguments of this function.

     - Parameters:
       - getState: a closure that allows the middleware to read the current state at any point in time
       - output: an action handler that allows the middleware to dispatch new actions at any point in time
     */
    func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>)

    /// Handles the incoming actions and may or not start async tasks, check the latest state at any point or dispatch additional actions.
    /// This is also a good place for analytics, tracking, logging and telemetry. You can schedule tasks to run after the reducer changed the global
    /// state if you want, and/or execute things before the reducer.
    /// This function is only called by the store after the `receiveContext(getState:output:)` was called, so if you saved the received context from
    /// there you can safely use it here to get the state or dispatch new actions.
    /// Setting the `afterReducer` in/out parameter is optional, if you don't set it, it defaults to `.doNothing()`.
    /// - Parameters:
    ///   - action: the action to be handled
    ///   - dispatcher: information about the action source, representing the entity that created and dispatched the action
    ///   - afterReducer: it can be set to perform any operation after the reducer has changed the global state. If the function ends before you set
    ///                   this in/out parameter, `afterReducer` will default to `.doNothing()`.
    func handle(action: InputActionType, from dispatcher: ActionSource, afterReducer: inout AfterReducer)
}

// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = StateType
// sourcery: AutoMockableGeneric = OutputActionType
// sourcery: AutoMockableGeneric = InputActionType
extension Middleware { }
