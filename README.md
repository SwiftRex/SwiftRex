<p align="center">
    <img alt="Swift" src="https://img.shields.io/badge/Swift-4.1-orange.svg">
    <a href="https://travis-ci.org/luizmb/SwiftRex" target="_blank">
        <img alt="Build Status" src="https://img.shields.io/travis/luizmb/SwiftRex.svg?branch=master&maxAge=600">
    </a>
    <a href='https://coveralls.io/github/luizmb/SwiftRex?branch=master' target="_blank">
        <img src='https://img.shields.io/coveralls/github/luizmb/SwiftRex.svg?branch=master&maxAge=600' alt='Coverage Status' />
    </a>
    <a href="https://github.com/Carthage/Carthage" target="_blank">
        <img alt="Carthage compatible" src="https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat">
    </a>
    <img alt="Platform" src="https://img.shields.io/badge/platform-iOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20macOS-lightgray.svg">
    <a href="https://github.com/luizmb/SwiftRex/blob/master/LICENSE">
        <img alt="GitHub license" src="https://img.shields.io/github/license/luizmb/SwiftRex.svg">
    </a>
</p>

# Introduction

SwiftRex is a framework that combines [event-sourcing pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/event-sourcing) and reactive programming ([RxSwift](https://github.com/ReactiveX/RxSwift)), providing a central state Store of which your ViewControllers can observe and react to, as well as dispatching events coming from the user interaction.

This pattern is also known as "Unidirectional Dataflow" or ["Redux"](https://redux.js.org/basics/data-flow).

# Goals

Several architectures and design patterns for mobile development nowadays propose to solve specific issues related to [Single Responsibility Principle](https://www.youtube.com/watch?v=Gt0M_OHKhQE) (such as Massive ViewControllers), or improve testability and dependency management. Other common challenges for mobile developers such as handling state, race conditions, thread-safety or dealing properly with UIKit life cycle and ownership are less explored but can be equally harmful for an app.

Managing all of these problems may sound like an impossible task that would require lots of patterns and really complex test scenarios. After all, how to to reproduce a rare but critical error that happens only with some of your users but never in developers' equipment? This can be frustrating and most of us has probably faced such problems from time to time.

That's the scenario where SwiftRex shines, because it:
- enforces the application of Single Responsibility Principle
- offers a clear test strategy for each layer
- isolates all the side-effects in middleware boxes
- minimizes the usage of dependencies on ViewControllers/Presenters/Interactors, so you don't have to keep sending dozens of dependencies across your views while routing through them
- detaches state, services, mutation and other side-effects completely from the UIKit life cycle and its ownership tree ([see why](Docs/UIKitLifetimeManagement.md))
- and last but not least, offers a proper state management offering a trustable truth that will never be inconsistent or out of sync among screens ([see why](Docs/StateManagement.md)).

I'm not gonna lie, it's a completely different way of writing apps, as most reactive approaches are; but once you get used to, it makes more sense and enables you to reuse much more code between your projects, gives you better tooling for writing software, testing, debugging, logging and finally thinking about events, state and mutation as you've never done before. And I promise you, it's gonna be a way with no return, an Unidirectional journey.

# Parts
- 🏪 [Store](#-store)
- 🕹 [Event](#-event)
- 🏄‍ [Action](#-action)
- ⛓️ [Middleware](#-middleware)
- 🌍 [SideEffectProducer](#-sideeffectproducer)
- ⚙️ [Reducer](#-reducer)

## 🏪 Store

That's where our journey begins. The store will glue everything together and its responsibility is being a proxy to the non-Redux world. For that reason, it implements two critical protocols for inputs and outputs: `EventHandler` and `StateProvider`.

Being an event handler means that ViewControllers can dispatch events to it, such as `userTappedButtonX`, `didScrollToPosition:`, `viewDidLoad` or `queryTextFieldChangedTo:`. On the other hand, being a state provider basically means that store is an `Observable<T>`, where `T` is the `State` of your app, so ViewControllers can subscribe to state changes and react to them. We will see how the communication flows later, but for now it's enough to understand that Store is the single point of contact with UIKit so it's a class that you want to inject as a dependency on all ViewControllers, either as one single dependency or, preferably, a dependency for each of its protocols - `EventHandler` and `StateProvider` -, both eventually pointing to the same instance but ViewController doesn't need to know that.

<p align="center">
  <img src="Docs/Misc/StoreBase.png" title="Store and ViewController">
</p>

In its documentation, Apple suggests some communication patterns between the MVC layers. Most important, they say that Controllers should update the Model, who notifies the Controller about changes:

<p align="center">
  <img src="Docs/Misc/CocoaMVC.gif" title="iOS MVC">
</p>

You can think of Store as a very heavy "Model" layer, completely detached from the View and Controller, and where all the business logic stands. At a first sight it may look like transfering the "Massive" problem from a layer to another, but later in this docs it's gonna be clear how the logic will be split and, hopefully, by having specialized middlewares we can even start sharing more code between different apps or different devices such as Apple TV, macOS, iOS, watchOS or backend APIs, thanks to the business decisions being completely off your presentation layer.

You want only one Store in your app, so either you create a singleton or a public property in a long-life class such as AppDelegate or AppCoordinator. That's crucial for making the store completely detached from the UIKit world. Theoretically it should be possible to keep multiple stores - one per module or per ViewController - and keep them in sync through Rx observation, in a "Flux"-like approach. However, the main goal of SwiftRex is to keep an unified state independent from UIKit, therefore it's the recommended approach.

A Store holds three important foundations:
- a Middleware pipeline
- a Reducer function
- current state

<p align="center">
  <img src="Docs/Misc/StoreInternals.png" title="Store internals">
</p>

## 🕹 Event

An event is usually a request from your user to which the app should respond, for example the tab bar icon was tapped, a menu item was selected, a swipe gesture from left to right on cell number 3 or a new character was pressed in a search bar. Other events can be generated by other actors, such as timers or GPS position, but let's skip that for a moment and thing exclusively about the main actor of most use cases: the user. Because the user interaction is given mainly throughout ViewControllers, we should agree that ViewControllers will create and dispatch most events to the Store.

Event is a marker protocol and usually you want to keep events as tiny value-type structures: `struct` or `enum`. Having associated values is completely optional, but please keep in mind that you should pass as minimum information as necessary, and avoid passing value that's already in the state.

For example, if there's a table view showing a list of movies, for each cell you may have a "Mark as Watched" (or Unwatched) button and a "Show Details" button, while the navigation bar has a button to mark all as watched. In that case, event enum could be:

```swift
enum MovieListEvent: Event {
    case didTapWatchToggle(rowIndex: Int)
    case didTapDetailsButton(rowIndex: Int)
    case didTapMarkAllAsWatched
}
```

Because your state already knows whether or not the movie was watched, you just need to offer a single "toggle" event instead of two events for watch or unwatch, and also there's no need for an extra boolean parameter. Moreover, you could pass the IndexPath.row instead of `movieId` so your enum becomes essentially a generic control event and your cells don't have to maintain IDs or any other model information.

## 🏄‍ Action

Like events, Action is also a marker protocol which concrete implementation is a value-type structure holding the associated value that is necessary to request a change in the state. Differently from events, although, actions have more meaningful values and are driven by business logic. While events represent taps in the interface and associated values like "3" or "true", an action is expected to hold the information required to mutate the state, such as: "got a new list of movies" with an associated values of `[Movie]`, or "delete invoice" and the associated value being the `Invoice` object. That way, we should not expect actions to be triggered by ViewControllers, only by Middlewares running in the Store. Some Middlewares can create one or multiple actions out of an event, collecting the proper state information from the indexes passed with the event, and then finally composing a very meaningful action that contains exactly the metadata for the change.

An event may end up not changing the state, but an action necessarily implies that the state will be mutated accordingly; for example the event "viewDidLoad" may not change your state, having the only purpose of logging or tracking analytics events (let's talk about side-effects later), and in that case don't change anything in the app; while an action "userHasLoggedIn" will necessarily change something on the state.

```swift
enum MovieListAction: Action {
    case setMovieAsWatched(movieId: UUID)
    case setMovieAsUnwatched(movieId: UUID)
    case setCurrentMovieDetailsPage(movie: Movie)
    case setMoviesAsWatched(movies: [Movie])
}
```

## ⛓ Middleware

We already know what events and actions are: both are lightweight structures that are dispatched (event) or triggered (action) into the Store. The store enqueues a new item that arrives and submits it to a pipeline of Middlewares. So, in other words, a Middleware is class that handles actions and events, and has the power to trigger more actions to the next Middlewares in the chain. A very simple Middleware will receive an Event and current state, and trigger an equivalent Action to the Store.

For example, the `MovieListEvent.didTapWatchToggle(rowIndex:)` shown before is handled by a middleware that checks the state and finds that current list has certain movie at the given row index, and this movie has been already marked as watched before. The Middleware was able to learn that thanks to the `getState: @escaping () -> StateType` closure received together with the Event, and which can be checked at any point to read an updated state. Our example Middleware then will trigger a `MovieListAction.setMovieAsUnwatched(movieId:)`.

However, this would be a very naive implementation. Most of the times we handle data that must be persisted in a database or through a REST API. State only lives in memory, but before changing the memory we should at least start Side-Effects. Let's revisit the example above and say that we got a `MovieListEvent.didTapWatchToggle(rowIndex:)` event. Yes, we still should check what movie is at that row and whether or not it's watched. Now, we can trigger a `URLSession` task requesting our API to mark it as unwatched. Because this request is asynchronous we have three options:
- assume that this API won't fail, and mark the movie immediately as unwatched;
- don't assume anything and wait for the HTTP Response;
- provide a very precise state management, meaning that we immediately change the state of our movie to "it's been changed" and, once we get the response we update again.

In the first case, we create the `URLSessionDataTask`, call `task.resume` and immediately trigger the `setMovieAsUnwatched` action. We may use the completion handler or the HTTP Request to confirm the result and rollback if needed. In the second case, after calling `task.resume` we don't trigger any action, only when we get the response in case it was successful one.

The third case, however, offers many more possibilities. You can think about the possible three states of a movie: watched, not watched, mutating. You can even split the "mutating" case in two: "mutating to watched" and "mutating to unwatched". What you get from that is the ability to disable the "watch" button, or replaced it by an activity indicator view or simply ignore further attempts to click it by ignoring the events when the movie is in this intermediate situation. To offer that, you call `task.resume` and immediately trigger a `setMovieAsUnwatchRequestInProgress`, while inside the response completion handler you evaluate the response and trigger another action to update the movie state again.

Because Middlewares access all events and the state of the app at any point, anything can be done in these small and reusable boxes. For example, the same CoreLocation middleware could be used from an iOS app, its extensions, the Apple Watch extension or even different apps, as long as they share some sub-state `struct`. Some suggestions of Middlewares:
- Run Timers, pooling some external resource or updating some local state at a constant time
- Subscribe for CoreData changes
- Subscribe for Realm changes
- Subscribe for Firebase Realtime Database notifications
- Be a CoreLocation delegate, checking for significant location changes or beacon ranges and triggering actions to update the state
- Be a HealthKit delegate to track activities, or even combining that with CoreLocation observation in order to track the activity route
- Logger
- Telemetry
- Analytics tracker
- WatchConnectivity sync, keep iOS and watchOS state in sync
- API calls and other "cold observables"
- Reachability
- Navigation through the app (Redux Coordinator pattern)
- `NotificationCenter` and other delegates
- RxSwift observables

## 🌍 SideEffectProducer

Some Middlewares are shipped with SwiftRex. While you're still welcome to create your own Middlewares from the scratch, some of the stock ones can offer you a shortcut. For RxSwift users we bring a `SideEffectMiddleware` that is a quick way to reuse your existing Observable pipelines. The Middleware requires the implementation of only one method:

```swift
func sideEffect(for event: Event) -> AnySideEffectProducer<StateType>?
```

Given an event, map it to a Side-Effect producer that handles such event. And what is a Side-Effect producer? It's a protocol with a single method to be implemented:

```swift
func execute(getState: @escaping GetState<StateType>) -> Observable<Action>
```

Given the current state (that can be checked consistently at any point), return an Observable sequence of `Action`. In your Rx pipeline you can trigger as many side-effects as you want, and every time an Action occurs you can easily notify the observer, that forwards it to the Store.

## ⚙ Reducer

The pipeline of Middlewares can trigger Actions, and handle both Events and Actions. But what they can NOT do is changing the app state. Middlewares have read-only access to the up-to-date state of our apps, but when mutations are required we use the "Reducer" function. Actually, it's a protocol that requires only one method:

```swift
func reduce(_ currentState: StateType, action: Action) -> StateType
```

Given the current state and an action, return the calculated state. This function will be executed in the last stage of an action handling, when all middlewares had the chance to modify or improve the action. Because a `reduce` function is composable, it's possible to write fine-grained "sub-reducer" that will handle only a "sub-state", creating a pipeline of reducers.

It's important to understand that reducer is a synchronous operations that calculates a new state without any kind of side-effect, so never add properties to the "Reducer" `structs` or call any external function. If you are tempted to do that, please create a middleware. Reducers are also responsible for keeping the consistency of a state, so it's always good to do a final sanity check before changing the state.

Once the reducer function executes, the store will update its single source of truth with the new calculated state, and propagate it to all its observers.