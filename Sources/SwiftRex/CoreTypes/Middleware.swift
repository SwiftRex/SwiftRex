/**
 ⛓ `Middleware` is a plugin, or a composition of several plugins, that are assigned to the `Store` pipeline in order
 to handle each `ActionType` dispatched and to execute side-effects in response, and eventually dispatch more
 `ActionType` in the process. This happens before the `Reducer` to do its job. So in other words, we can think of
 a Middleware as an object that transforms `ActionType` into sync or async tasks and create more actions as these
 side-effects complete, also being able to check the current state at any point.

 An `ActionType` is a lightweight structure that is dispatched into the `Store`. The store enqueues a new item that
 arrives and submits it to a pipeline of middlewares. So, in other words, a `Middleware` is class that handles actions,
 and has the power to dispatch more actions to the `ActionHandler` chain. The `Middleware` can ignore the action and
 simply delegate to the next node in the chain of middlewares, or it can execute side-effects in response, such as
 logging into file or over the network, or execute http requests, for example. In case of those async tasks, when they
 complete the middleware can dispatch new actions containing a payload with the response (a JSON file, an array of
 movies, credentials, etc). Other middlewares will handle that, or maybe even the same middleware in a future RunLoop,
 or perhaps some `Reducer`, as reducers pipeline is at the end of every middleware pipeline.

 Because we control when the next node will be called, we can for example collect the state before and after reducers
 have changed the state, which can be very interesting for logging, auditing, analytics tracking, telemetry or state
 synchronization with external devices, such as Apple Watches or debugging tools over the network.

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
 `URLSession` task requesting our API to mark it as unwatched. Because this request is asynchronous we have three options:

 - assume that this API won't fail, and mark the movie immediately as unwatched;
 - don't assume anything and wait for the `HTTPResponse`;
 - provide a very precise state management, meaning that we immediately change the state of our movie to "it's being
 changed" and, once we get the response we update again.

 In the first case, we create the `URLSessionDataTask`, call `task.resume()` and immediately trigger the
 `setMovieAsUnwatched` action. We may use the completion handler or the `HTTPRequest` to confirm the result and rollback
 if needed. In the second case, after calling `task.resume()` we don't trigger any action, only when we get the response
 in case it was successful one.

 The third case, however, offers many more possibilities. You can think about the possible three states of a movie:
 watched, not watched, mutating. You can even split the "mutating" case in two: "mutating to watched" and "mutating to
 unwatched". What you get from that is the ability to disable the "watch" button, or replaced it by an activity indicator
 view or simply ignore further attempts to click it by ignoring the events when the movie is in this intermediate
 situation. To offer that, you call `task.resume` and immediately trigger an Action `setMovieAsUnwatchRequestInProgress`,
 which will eventually set the state accordingly, while inside the response completion handler you evaluate the response
 and trigger another action to update the movie state again, by triggering either `setMovieAsUnwatched` in case of
 successful response, or back to `setMovieAsWatched` if the operation fails. In case of failure you may also consider
 to trigger an additional Action `gotError` so you notify the user, or maybe implement a retry.

 Because the `Middleware` accesses all actions and the state of the app at any point, anything can be done in these
 small and reusable boxes. For example, the same `CoreLocation` middleware could be used from an iOS app, its extensions,
 the Apple Watch extension or even different apps, as long as they share some sub-state struct. Some suggestions of
 middlewares:

 - Run Timers, pooling some external resource or updating some local state at a constant time
 - Subscribe for `CoreData` changes
 - Subscribe for `Realm` changes
 - Subscribe for `Firebase Realtime Database` notifications
 - Be a `CoreLocation` delegate, checking for significant location changes or beacon ranges and triggering actions to
 update the state
 - Be a `HealthKit` delegate to track activities, or even combining that with `CoreLocation` observation in order to
 track the activity route
 - Logger
 - Telemetry
 - Analytics tracker
 - `WatchConnectivity` sync, keep iOS and watchOS state in sync
 - API calls and other "cold observables"
 - Network Reachability
 - Navigation through the app (Redux Coordinator pattern)
 - `CoreBluetooth` central or peripheral manager
 - `CoreNFC`
 - `NotificationCenter` and other delegates
 - `RxSwift` observables, `ReactiveSwift` signal producers, `Combine` publishers
 - Any side-effect, I/O, networking, sensors, third-party libraries that you want to abstract
 */
public protocol Middleware: class {
    /**
     The Action that this `Middleware` knowns how to handle. Thanks to optics, this action can be a sub-action lifted to
     a global action type. Please check `lift(actionMap:actionContramap:stateMap:stateContramap:)` for more details.
     */
    associatedtype ActionType

    /**
     The State that this `Middleware` knowns how to handle. Thanks to lenses, this state can be a sub-state lifted to
     a global state. Please check `lift(actionMap:actionContramap:stateMap:stateContramap:)` for more details.
     */
    associatedtype StateType

    /**
     Every `Middleware` needs some context in order to be able to interface with other middleware and with the store.
     This context includes ways to fetch the most up-to-date state, dispatch new actions or call the next middleware in
     the chain.
     */
    var context: (() -> MiddlewareContext<ActionType, StateType>) { get set }

    /**
     Handles the incoming actions and may or not start async tasks, check the latest state at any point or dispatch
     additional actions. This is also a good place for analytics, tracking, logging and telemetry.
     - Parameters:
       - action: the action to be handled
       - next: opportunity to call the next middleware in the chain and, eventually, the reducer pipeline. Call it
               only once, not more or less than once.
     */
    func handle(action: ActionType, next: @escaping Next)
}

// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = StateType
// sourcery: AutoMockableGeneric = ActionType
// sourcery: TypeErase = StateType
// sourcery: TypeErase = ActionType
extension Middleware { }
