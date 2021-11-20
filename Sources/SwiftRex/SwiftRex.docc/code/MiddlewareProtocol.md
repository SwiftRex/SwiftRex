# ``SwiftRex/MiddlewareProtocol``

We can think of a Middleware as an object that transforms actions into sync or async tasks and create more actions as these side-effects complete, also being able to check the current state while handling an action.

An <doc:Action> is a lightweight structure, typically an enum, that is dispatched into the ``ActionHandler`` (usually a ``StoreType``).

A Store like ``ReduxStoreProtocol`` enqueues a new action that arrives and submits it to a pipeline of middlewares. So, in other words, a ``MiddlewareProtocol`` is class that handles actions, and has the power to dispatch more actions, either immediately or after callback of async tasks. The middleware can also simply ignore the action, or it can execute side-effects in response, such as logging into file or over the network, or execute http requests, for example. In case of those async tasks, when they complete the middleware can dispatch new actions containing a payload with the response (a JSON file, an array of movies, credentials, etc). Other middlewares will handle that, or maybe even the same middleware in the future, or perhaps some ``Reducer`` will use this action to change the state, because the ``MiddlewareProtocol`` itself can never change the state, only read it.

The ``MiddlewareProtocol/handle(action:from:state:)`` will be called before the Reducer, so if you read the state at that point it's still going to be the unchanged version. While implementing this function, it's expected that you return an ``IO`` object, which is basically a closure where you can perform side-effects and dispatch new actions. Inside this closure, the state will have the new values after the reducers handled the current action, so in case you made a copy of the old state, you can compare them, log, audit, perform analytics tracking, telemetry or state sync with external devices, such as Apple Watches. Remote Debugging over the network is also a great use of a Middleware.

Every action dispatched also comes with its action source, which is the primary dispatcher of that action. Middlewares can access the file name, line of code, function name and additional information about the entity responsible for creating and dispatching that action, which is a very powerful debugging information that can help developers to trace how the information flows through the app.

Ideally a ``MiddlewareProtocol`` should be a small and reusable box, handling only a very limited set of actions, and combined with other small middlewares to create more complex apps. For example, the same `CoreLocation` middleware could be used from an iOS app, its extensions, the Apple Watch extension or even different apps, as long as they share some sub-action tree and sub-state struct.

Some suggestions of middlewares:

- Run Timers, pooling some external resource or updating some local state at a constant time
- Subscribe for `CoreData`, `Realm`, `Firebase Realtime Database` or equivalent database changes
- Be a `CoreLocation` delegate, checking for significant location changes or beacon ranges and triggering actions to update the state
- Be a `HealthKit` delegate to track activities, or even combining that with `CoreLocation` observation in order to track the activity route
- Logger, Telemetry, Auditing, Analytics tracker, Crash report breadcrumbs
- Monitoring or debugging tools, like external apps to monitor the state and actions remotely from a different device
- `WatchConnectivity` sync, keep iOS and watchOS state in sync
- API calls and other "cold observables"
- Network Reachability
- Navigation through the app (Redux Coordinator pattern)
- `CoreBluetooth` central or peripheral manager
- `CoreNFC` manager and delegate
- `NotificationCenter` and other delegates
- WebSocket, TCP Socket, Multipeer and many other connectivity protocols
- `RxSwift` observables, `ReactiveSwift` signal producers, `Combine` publishers
- Observation of traits changes, device rotation, language/locale, dark mode, dynamic fonts, background/foreground state
- Any side-effect, I/O, networking, sensors, third-party libraries that you want to abstract

```
                                                                                                                    ┌────────┐                                     
                                                       IO closure                                                ┌─▶│ View 1 │                                     
                      ┌─────┐                          (don't run yet)                       ┌─────┐             │  └────────┘                                     
                      │     │ handle  ┌──────────┐  ┌───────────────────────────────────────▶│     │ send        │  ┌────────┐                                     
                      │     ├────────▶│Middleware│──┘                                        │     │────────────▶├─▶│ View 2 │                                     
                      │     │ Action  │ Pipeline │──┐  ┌─────┐ reduce ┌──────────┐           │     │ New state   │  └────────┘                                     
                      │     │         └──────────┘  └─▶│     │───────▶│ Reducer  │──────────▶│     │             │  ┌────────┐                                     
    ┌──────┐ dispatch │     │                          │Store│ Action │ Pipeline │ New state │     │             └─▶│ View 3 │                                     
    │Button│─────────▶│Store│                          │     │ +      └──────────┘           │Store│                └────────┘                                     
    └──────┘ Action   │     │                          └─────┘ State                         │     │                                   dispatch    ┌─────┐         
                      │     │                                                                │     │       ┌─────────────────────────┐ New Action  │     │         
                      │     │                                                                │     │─run──▶│       IO closure        ├────────────▶│Store│─ ─ ▶ ...
                      │     │                                                                │     │       │                         │             │     │         
                      │     │                                                                │     │       └─┬───────────────────────┘             └─────┘         
                      └─────┘                                                                └─────┘         │                     ▲                               
                                                                                                      request│ side-effects        │side-effects                   
                                                                                                             ▼                      response                       
                                                                                                        ┌ ─ ─ ─ ─ ─                │                               
                                                                                                          External │─ ─ async ─ ─ ─                                
                                                                                                        │  World                                                   
                                                                                                         ─ ─ ─ ─ ─ ┘                                               
```

#### Generics

Middleware protocol is generic over 3 associated types:

- ``InputActionType``:

    The Action type that this ``MiddlewareProtocol`` knows how to handle, so the store will forward actions of this type to this middleware.
    
    Most of the times middlewares don't need to handle all possible actions from the whole global action tree, so we can decide to allow it to
    focus only on a subset of the action.
    
    In this case, this action type can be a subset to be lifted to a global action type in order to compose with other middlewares acting on the
    global action of an app. Please check <doc:Lifting> for more details.

- ``OutputActionType``:

    The Action type that this ``MiddlewareProtocol`` will eventually trigger back to the store in response of side-effects. This can be the same
    as ``InputActionType`` or different, in case you want to separate your enum in requests and responses.
    
    Most of the times middlewares don't need to dispatch all possible actions of the whole global action tree, so we can decide to allow it to
    dispatch only a subset of the action, or not dispatch any action at all, so the ``OutputActionType`` can safely be set to `Never`.
    
    In this case, this action type can be a subset to be lifted to a global action type in order to compose with other middlewares acting on the
    global action of an app. Please check <doc:Lifting> for more details.

- ``StateType``:

    The State part that this ``MiddlewareProtocol`` needs to read in order to make decisions. This middleware will be able to read the most
    up-to-date ``StateType`` from the store while handling an incoming action, but it can never write or make changes to it.
    
    Most of the times middlewares don't need reading the whole global state, so we can decide to allow it to read only a subset of the state, or
    maybe this middleware doesn't need to read any state, so the ``StateType`` can safely be set to `Void`.
    
    In this case, this state type can be a subset to be lifted to a global state in order to compose with other middlewares acting on the global state
    of an app. Please check <doc:Lifting> for more details.

#### Returning IO and performing side-effects

In its most important function, ``MiddlewareProtocol/handle(action:from:state:)`` the middleware is expected to return an ``IO`` object, which is a closure where side-effects should be executed and new actions can be dispatched.

In some cases, we may want to not execute any side-effect or run any code after reducer, in that case, the function can return a simple ``IO/pure()``.

Otherwise, return the closure that takes the `output` (of ``ActionHandler`` type, that accepts ``ActionHandler/dispatch(_:)`` calls):
```swift
public func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType> {
    if action != .myExpectedAction { return .pure() }

    return IO { output in 
        output.dispatch(.showPopup)
        DispatchQueue.global().asyncAfter(.now() + .seconds(3)) { 
            output.dispatch(.hidePopup)
        }
    }
}
```

#### Dependency Injection

Testability is one of the most important aspects to account for when developing software. In Redux architecture, ``MiddlewareProtocol`` is the only type of object allowed to perform side-effects, so it's the only place where the testability can be challenging.

To improve testability, the middleware should use as few external dependencies as possible. If it starts to use too many, consider splitting in smaller middlewares, this will also protect you against race conditions and other problems, will help with tests and make the middleware more reusable.

Also, all external dependencies should be injected in the initialiser, so during the tests you can replace them with mocks. If your middleware uses only one call from a very complex object, instead of using a protocol full of functions please consider either creating a protocol with a single function requirement, or even inject a closure such as `@escaping (URLRequest) -> AnyPublisher<(Data, URLResponse), Error>`. Creating mocks for this will be way much easier.

Finally, consider using ``MiddlewareReader`` to wrap this middleware in a dependency injection container.

#### Examples

When implementing your Middleware, all you have to do is to handle the incoming actions:

```swift
public final class LoggerMiddleware: MiddlewareProtocol {
    public typealias InputActionType = AppGlobalAction // It wants to receive all possible app actions
    public typealias OutputActionType = Never          // No action is generated from this Middleware
    public typealias StateType = AppGlobalState        // It wants to read the whole app state

    private let logger: Logger
    private let now: () -> Date

    // Dependency Injection
    public init(logger: Logger = Logger.default, now: @escaping () -> Date) {
        self.logger = logger
        self.now = now
    }

    //            inputAction: AppGlobalAction                                                state: AppGlobalState     output action: Never  
    public func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType> {
        let stateBefore: AppGlobalState = state()
        let dateBefore = now()

        return IO { [weak self] output in
            guard let self = self else { return }
            let stateAfter = state()
            let dateAfter = self.now()
            let source = "\(dispatcher.file):\(dispatcher.line) - \(dispatcher.function) | \(dispatcher.info ?? "")"

            self.logger.log(action: action, from: source, before: stateBefore, after: stateAfter, dateBefore: dateBefore, dateAfter: dateAfter)
        }
    }
}

public final class FavoritesAPIMiddleware: MiddlewareProtocol {
    public typealias InputActionType = FavoritesAction  // It wants to receive only actions related to Favorites
    public typealias OutputActionType = FavoritesAction // It wants to also dispatch actions related to Favorites
    public typealias StateType = FavoritesModel         // It wants to read the app state that manages favorites

    private let api: API

    // Dependency Injection
    public init(api: API) {
        self.api = api
    }

    //            inputAction: FavoritesAction                                                state: FavoritesModel     output action: FavoritesAction  
    public func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType> {
        guard case let .toggleFavorite(movieId) = action else { return .pure() }
        let favoritesList = state() // state before reducer
        let makeFavorite = !favoritesList.contains(where: { $0.id == movieId })

        return IO { [weak self] output in
            guard let self = self else { return }

            self.api.changeFavorite(id: movieId, makeFavorite: makeFavorite) (completion: { result in
                switch result {
                case let .success(value):
                    output.dispatch(.changedFavorite(movieId, isFavorite: makeFavorite), info: "API.changeFavorite callback")
                case let .failure(error):
                    output.dispatch(.changedFavoriteHasFailed(movieId, isFavorite: !makeFavorite, error: error), info: "api.changeFavorite callback")
                }
            })

        }
    }
}
```

#### WWDC slide about SwiftUI

![SwiftUI Side-Effects](wwdc2019-226-02)
