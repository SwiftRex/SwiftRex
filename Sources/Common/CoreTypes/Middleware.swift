/**
 ⛓ `Middleware` is a plugin, or a composition of several plugins, that are assigned to the `Store` pipeline in order to handle each `EventProtocol` dispatched and to create `ActionProtocol` in response. It's also capable of handling each `ActionProtocol` before the `Reducer` to do its job.

 We already know what `EventProtocol` and `ActionProtocol` are: both are lightweight structures that are dispatched (event) or triggered (action) into the `Store`. The store enqueues a new item that arrives and submits it to a pipeline of middlewares. So, in other words, a `Middleware` is class that handles actions and events, and has the power to trigger more actions to the `ActionHandler` chain. A very simple `Middleware` will receive an `EventProtocol` and current state, and trigger an equivalent `ActionProtocol` to the `Store`.

 For example, a `MovieListEvent.didTapWatchToggle(rowIndex:)` event would be handled by a `Middleware` that checks the state and finds that current list has certain movie at the given row index, and this movie has been already marked as watched before. That `Middleware` was able to learn that thanks to the `getState: @escaping () -> StateType` closure received together with the `EventProtocol`, and which can be checked at any point to read an updated state. Our example `Middleware` then will trigger a `MovieListAction.setMovieAsUnwatched(movieId:)` action to be handled by itself, other middlewares or the `Reducer` chain.

 However, this would be a very naive implementation. Most of the times we handle data that must be persisted in a database or through a REST API. State only lives in memory, but before changing the memory we should at least start Side-Effects. Let's revisit the example above and say that we got a `MovieListEvent.didTapWatchToggle(rowIndex:)` event. Yes, we still should check what movie is at that row and whether or not it's watched. Now, we can trigger a `URLSession` task requesting our API to mark it as unwatched. Because this request is asynchronous we have three options:

 - assume that this API won't fail, and mark the movie immediately as unwatched;
 - don't assume anything and wait for the `HTTPResponse`;
 - provide a very precise state management, meaning that we immediately change the state of our movie to "it's being changed" and, once we get the response we update again.

 In the first case, we create the `URLSessionDataTask`, call `task.resume()` and immediately trigger the `setMovieAsUnwatched` action. We may use the completion handler or the `HTTPRequest` to confirm the result and rollback if needed. In the second case, after calling `task.resume()` we don't trigger any action, only when we get the response in case it was successful one.

 The third case, however, offers many more possibilities. You can think about the possible three states of a movie: watched, not watched, mutating. You can even split the "mutating" case in two: "mutating to watched" and "mutating to unwatched". What you get from that is the ability to disable the "watch" button, or replaced it by an activity indicator view or simply ignore further attempts to click it by ignoring the events when the movie is in this intermediate situation. To offer that, you call task.resume and immediately trigger a `setMovieAsUnwatchRequestInProgress`, while inside the response completion handler you evaluate the response and trigger another action to update the movie state again.

 Because the `Middleware` accesses all events and the state of the app at any point, anything can be done in these small and reusable boxes. For example, the same `CoreLocation` middleware could be used from an iOS app, its extensions, the Apple Watch extension or even different apps, as long as they share some sub-state struct. Some suggestions of middlewares:

 - Run Timers, pooling some external resource or updating some local state at a constant time
 - Subscribe for `CoreData` changes
 - Subscribe for `Realm` changes
 - Subscribe for `Firebase Realtime Database` notifications
 - Be a `CoreLocation` delegate, checking for significant location changes or beacon ranges and triggering actions to update the state
 - Be a `HealthKit` delegate to track activities, or even combining that with `CoreLocation` observation in order to track the activity route
 - Logger
 - Telemetry
 - Analytics tracker
 - `WatchConnectivity` sync, keep iOS and watchOS state in sync
 - API calls and other "cold observables"
 - Reachability
 - Navigation through the app (Redux Coordinator pattern)
 - `NotificationCenter` and other delegates
 - `RxSwift` observables or `ReactiveSwift` signal producers
 */
public protocol Middleware: class {

    /**
     The State that this `Middleware` knowns how to handle. Thanks to lenses, this state can be a sub-state lifted to a global state. Please check `lift(_:)` for more details.
     */
    associatedtype StateType

    /**
     A `Middleware` is capable of triggering `ActionProtocol` to the `Store`. This property is a nullable `ActionHandler` used for the middleware to trigger the actions. It's gonna be injected by the `Store` or by a parent `Middleware`, so don't worry about it, just use it whenever you need to trigger something.
     */
    var actionHandler: ActionHandler? { get set }

    /**
     Handles the incoming events and may trigger side-effects, may trigger actions, may start an asynchronous operation.
     - Parameters:
       - event: the event to be handled
       - getState: a function that can be used to get the current state at any point in time
       - next: the next `Middleware in the chain, probably we want to call this method in some point of our method (not necessarily in the end.
     */
    func handle(event: EventProtocol, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>)

    /**
     Handles the incoming actions and may change them or trigger additional ones. Usually this is not the best place to start side-effects or trigger new actions, it should be more as an observation point for tracking, logging and telemetry.
     - Parameters:
       - action: the action to be handled
       - getState: a function that can be used to get the current state at any point in time
       - next: the next `Middleware` in the chain, probably we want to call this method in some point of our method (not necessarily in the end. When this is the last middleware in the pipeline, the next function will call the `Reducer` pipeline.
     */
    func handle(action: ActionProtocol, getState: @escaping GetState<StateType>, next: @escaping NextActionHandler<StateType>)
}

// sourcery: TypeErase = StateType
extension Middleware { }
