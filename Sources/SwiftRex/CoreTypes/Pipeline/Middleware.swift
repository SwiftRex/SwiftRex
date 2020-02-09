/**
 ⛓ `Middleware` is a plugin, or a composition of several plugins, that are assigned to the `Store` pipeline in order
 to handle each action received (`InputActionType`), to execute side-effects in response, and eventually dispatch more
 action (`OutputActionType`) in the process. This happens before the `Reducer` to do its job. So in other words, we can
 think of a Middleware as an object that transforms actions into sync or async tasks and create more actions as these
 side-effects complete, also being able to check the current state at any point.

 An action is a lightweight structure that is dispatched into the `Store`. The store enqueues a new action that arrives
 and submits it to a pipeline of middlewares. So, in other words, a `Middleware` is class that handles actions, and has
 the power to dispatch more actions to the `ActionHandler` chain. The `Middleware` can ignore the action and simply
 delegate to the next node in the chain of middlewares, or it can execute side-effects in response, such as logging into
 file or over the network, or execute http requests, for example. In case of those async tasks, when they complete the
 middleware can dispatch new actions containing a payload with the response (a JSON file, an array of movies,
 credentials, etc). Other middlewares will handle that, or maybe even the same middleware in a future RunLoop, or
 perhaps some `Reducer`, as reducers pipeline is at the end of every middleware pipeline.

 Because we control when the next node will be called, we can for example collect the state before and after reducers
 have changed the state, which can be very interesting for logging, auditing, analytics tracking, telemetry or state
 synchronization with external devices, such as Apple Watches or for debugging tools over the network.

 So let's imagine a movie catalog app where a `MovieListAction.didTapWatchToggle(rowIndex:)` action would be handled by
 a `Middleware` that checks the state and finds that current list has certain movie at the given row index, and this
 movie has been already marked as watched before. The `Middleware` was able to learn that thanks to the
 `getState: @escaping () -> StateType` closure present in the property `context` of type `MiddlewareContext`, which can
 be checked at any point to read an updated state. Our example `Middleware` then will trigger a
 `MovieListAction.setMovieAsUnwatched(movieId:)` action to be handled by itself, other middlewares or the `Reducer` chain.

 However, this would be a very naive implementation. Most of the times we handle data that must be persisted in a
 database or through a REST API. State only lives in memory, but before changing the memory we should at least start
 Side-Effects. Let's revisit the example above and say that we got a `MovieListAction.didTapWatchToggle(rowIndex:)`
 action. Yes, we still should check what movie is at that row and whether or not it's watched. Now, we can trigger an
 http task requesting our API to mark it as unwatched. Because this request is asynchronous we have three options:

 - assume that this API won't fail, and mark the movie immediately as unwatched;
 - don't assume anything and wait for the `HTTPResponse`;
 - provide a very precise state management, meaning that we immediately change the state of our movie to "it's being
 changed" and, once we get the response we update again.

 In the first case, we create the `URLSessionDataTask`, call `task.resume()` and immediately trigger the
 `setMovieAsUnwatched` action for the reducer to update the app state. We may use the completion handler of the
 `HTTPRequest` to confirm the successful result and rollback if needed, by sending another action so the reducer will
 revert the change in the state, and the UI will then react to that.

 In the second case, after calling `task.resume()` we don't trigger any action, only when we get the response we trigger
 the action that will eventually change the state and the UI, of course in case it was a successful response.

 The third case, however, offers many more possibilities. You can think about the possible three states of a movie:
 watched, not watched, mutating. You can even split the "mutating" case in two: "mutating to watched" and "mutating to
 unwatched". So instead of a boolean with `true` or `false`, now your state is an enum with four cases, describing
 precisely the situation of your element. What you get from that is the ability to perform better animations, improved
 UI features like disable the "watch" button while the change is being requested, use activity indicators view or simply
 ignore further attempts to click the Toggle in the screen, by ignoring the events while the movie is in this intermediate
 situation. To offer that, you call `task.resume` and immediately trigger an Action `setMovieAsUnwatchRequestInProgress`,
 which will eventually set the state accordingly, while inside the response completion handler you evaluate the response
 and trigger another action to update the movie state again, by triggering either `setMovieAsUnwatched` in case of
 successful response, or back to `setMovieAsWatched` if the operation fails. In case of failure you may also consider
 to trigger an additional Action `gotError` so you notify the user, or maybe implement a retry.

 Because the `Middleware` receive all actions and accesses the state of the app at any point, anything can be done from
 these small and reusable boxes. For example, the same `CoreLocation` middleware could be used from an iOS app, its
 extensions, the Apple Watch extension or even different apps, as long as they share some sub-state struct.

 Some suggestions of middlewares:

 - Run Timers, pooling some external resource or updating some local state at a constant time
 - Subscribe for `CoreData`, `Realm`, `Firebase Realtime Database` or equivalent database changes
 - Be a `CoreLocation` delegate, checking for significant location changes or beacon ranges and triggering actions to
 update the state
 - Be a `HealthKit` delegate to track activities, or even combining that with `CoreLocation` observation in order to
 track the activity route
 - Logger, Telemetry, Auditing, Analytics tracker, Crash report breadcrumbs
 - `WatchConnectivity` sync, keep iOS and watchOS state in sync
 - Monitoring or debugging tools, like external apps to monitor the state and actions remotely from a different device
 - API calls and other "cold observables"
 - Network Reachability
 - Navigation through the app (Redux Coordinator pattern)
 - `CoreBluetooth` central or peripheral manager
 - `CoreNFC`
 - `NotificationCenter` and other delegates
 - `RxSwift` observables, `ReactiveSwift` signal producers, `Combine` publishers
 - Observation of traits changes, device rotation, language/locale, dark mode, dynamic fonts, background/foreground state
 - Any side-effect, I/O, networking, sensors, third-party libraries that you want to abstract

 When implementing your Middleware, all you have to do is to handle the incoming actions:
 ```
 class MyMiddleware: Middleware {
     var context: (() -> MiddlewareContext<SomeActionType, SomeStateType>) = { fatalError("Store will set this") }

     func handle(action: SomeActionType, next: @escaping Next) {
         guard action == .requestNetwork else {
             next()
             return
         }

         requestMyFavoriteAPI(completion: { result in
             switch result {
             case let .success(value): context().dispatch(.gotSuccessfulValue(value))
             case let .failure(error): context().dispatch(.gotFailure(error))
             }
         })

         next()
     }
 }
 ```

 Some important notes about the code above, and generally speaking about any middleware:
 - Always call `next()`. If you have an early exit by using `guard`, don't forget to call there and in the regular case too.
 - Never call `next()` more than once. Seriously, you don't want that.
 - Most of the time you can consider calling `next()` in a `defer` block put at the beginning of your function.
 - Although that would work somehow, please don't call `next()` in a callback or dispatch queue async/sync block. Call it
 exactly in the thread you got it, and in the same runloop. Unless you REALLY know what you're doing.
 - Anything before `next()` happens before the state change, what comes after `next()` will happen after the reducer chain
 so you can you that to track state changes:
 ```
 func handle(action: SomeActionType, next: @escaping Next) {
     let stateBefore = context().getState()
     let dateBefore = Date()

     next()

     let stateAfter = context().getState()
     let dateAfter = Date()

     log(action: action, before: stateBefore, after: stateAfter, dateBefore: dateBefore, dateAfter: dateAfter)
 }
 ```
 ```
                   ┌─────┐                                                                                        ┌─────┐
                   │     │     handle   ┌──────────┐ request      ┌ ─ ─ ─ ─  response     ┌──────────┐ dispatch   │     │
                   │     │   ┌─────────▶│Middleware├─────────────▶ External│─────────────▶│Middleware│───────────▶│Store│─ ─ ▶ ...
                   │     │   │ Action   │ Pipeline │ side-effects │ World    side-effects │ callback │ New Action │     │
                   │     │   │          └──────────┘               ─ ─ ─ ─ ┘              └──────────┘            └─────┘
 ┌──────┐ dispatch │     │   │
 │Button│─────────▶│Store│──▶│                                                         ┌────────┐
 └──────┘ Action   │     │   │                                                      ┌─▶│ View 1 │
                   │     │   │                                  ┌─────┐             │  └────────┘
                   │     │   │ reduce   ┌──────────┐            │     │ onNext      │  ┌────────┐
                   │     │   └─────────▶│ Reducer  ├───────────▶│Store│────────────▶├─▶│ View 2 │
                   │     │     Action   │ Pipeline │ New state  │     │ New state   │  └────────┘
                   └─────┘     +        └──────────┘            └─────┘             │  ┌────────┐
                               State                                                └─▶│ View 3 │
                                                                                       └────────┘
 ```
 */
public protocol Middleware {
    /**
     The Action type that this `Middleware` knowns how to handle, so the store will forward actions of this type to this
     middleware. Thanks to optics, this action can be a sub-action lifted to a global action type. Please check
     `lift(actionZoomIn:actionZoomOut:stateZoomIn:)` for more details.
     */
    associatedtype InputActionType

    /**
     The Action type that this `Middleware` will eventually trigger back to the store in response of side-effects. This
     can be the same as `InputActionType` or different, in case you want to separate your enum in requests and responses.
     Thanks to optics, this action can be a sub-action lifted to a global action type. Please check
     `lift(actionZoomIn:actionZoomOut:stateZoomIn:)` for more details.
     */
    associatedtype OutputActionType

    /**
     The State that this `Middleware` knowns how to handle. Thanks to lenses, this state can be a sub-state lifted to
     a global state. Please check `lift(actionZoomIn:actionZoomOut:stateZoomIn:)` for more details.
     */
    associatedtype StateType

    /**
     Middleware setup. This function will be called before actions are handled to the middleware, so you can configure your middleware with the given
     parameters. You can hold any of them if you plan to read the state or dispatch new actions.
     You can initialize and start timers or async tasks in here or in the `handle(action:next)` function, but never before this function is called,
     otherwise the middleware would not yet be running from a store.

     - Parameters:
       - getState: a closure that allows the middleware to read the current state at any point in time
       - output: an action handler that allows the middleware to dispatch new actions at any point in time
     */
    func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>)

    /// Handles the incoming actions and may or not start async tasks, check the latest state at any point or dispatch additional actions.
    /// This is also a good place for analytics, tracking, logging and telemetry. You can schedule tasks to run after the reducer changed the global
    /// state.
    /// - Parameters:
    ///   - action: the action to be handled
    ///   - dispatcher: information about the action source, representing the entity that created and dispatched the action
    ///   - afterReducer: it can be set to perform any operation after the reducer has changed the global state
    func handle(action: InputActionType, from dispatcher: ActionSource, afterReducer: inout AfterReducer)
}

// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = StateType
// sourcery: AutoMockableGeneric = OutputActionType
// sourcery: AutoMockableGeneric = InputActionType
extension Middleware { }
