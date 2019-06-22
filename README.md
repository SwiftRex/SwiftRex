# SwiftRex

[![Build Status](https://api.travis-ci.org/SwiftRex/SwiftRex.svg?branch=develop)](https://travis-ci.org/SwiftRex/SwiftRex)
[![Coverage Status](https://img.shields.io/coveralls/github/SwiftRex/SwiftRex.svg?branch=develop&maxAge=600)](https://coveralls.io/github/SwiftRex/SwiftRex?branch=develop)
[![Jazzy Documentation](https://swiftrex.github.io/SwiftRex/api/badge.svg)](https://swiftrex.github.io/SwiftRex/api/index.html)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-orange.svg)](https://github.com/Carthage/Carthage)
[![CocoaPods compatible](https://img.shields.io/cocoapods/v/SwiftRex.svg)](https://cocoapods.org/pods/SwiftRex)
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-orange.svg)](https://github.com/apple/swift-package-manager)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
[![Platform support](https://img.shields.io/badge/platform-iOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20macOS-252532.svg)](https://github.com/SwiftRex/SwiftRex)
[![License Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/SwiftRex/SwiftRex/blob/master/LICENSE)

# Introduction

SwiftRex is a framework that combines [event-sourcing pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/event-sourcing) and reactive programming ([RxSwift](https://github.com/ReactiveX/RxSwift) or [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift)), providing a central state Store of which your ViewControllers can observe and react to, as well as dispatching events coming from the user interaction.

This pattern is also known as "Unidirectional Dataflow" or ["Redux"](https://redux.js.org/basics/data-flow).

[API documentation can be found here](https://swiftrex.github.io/SwiftRex/api/index.html).

# Goals

Several architectures and design patterns for mobile development nowadays propose to solve specific issues related to [Single Responsibility Principle](https://www.youtube.com/watch?v=Gt0M_OHKhQE) (such as Massive ViewControllers), or improve testability and dependency management. Other common challenges for mobile developers such as handling state, race conditions, thread-safety or dealing properly with UIKit life cycle and ownership are less explored but can be equally harmful for an app.

Managing all of these problems may sound like an impossible task that would require lots of patterns and really complex test scenarios. After all, how to to reproduce a rare but critical error that happens only with some of your users but never in developers' equipment? This can be frustrating and most of us has probably faced such problems from time to time.

That's the scenario where SwiftRex shines, because it:
- enforces the application of Single Responsibility Principle
- offers a clear test strategy for each layer
- isolates all the side-effects in middleware boxes
- minimizes the usage of dependencies on ViewControllers/Presenters/Interactors, so you don't have to keep sending dozens of dependencies across your views while routing through them
- detaches state, services, mutation and other side-effects completely from the UIKit life cycle and its ownership tree ([see why](docs/markdown/UIKitLifetimeManagement.md))
- and last but not least, offers a proper state management offering a trustable truth that will never be inconsistent or out of sync among screens ([see why](docs/markdown/StateManagement.md)).

I'm not gonna lie, it's a completely different way of writing apps, as most reactive approaches are; but once you get used to, it makes more sense and enables you to reuse much more code between your projects, gives you better tooling for writing software, testing, debugging, logging and finally thinking about events, state and mutation as you've never done before. And I promise you, it's gonna be a way with no return, an Unidirectional journey.

# Parts
- 🏪 [Store](#-store)
- 🕹 [Event](#-eventprotocol)
- 🏄‍ [Action](#-actionprotocol)
- ⛓️ [Middleware](#-middleware)
- 🌍 [SideEffectProducer](#-sideeffectproducer)
- ⚙️ [Reducer](#-reducer)

## 🏪 Store

 `Store` defines a protocol for the state store of an app. It must have an input and an output:
 - an `EventHandler`: that's the store input, so it's able to receive and distribute events of type `EventProtocol`. Being an event handler means that an `UIViewController` can dispatch events to it, such as `.userTappedButtonX`, `.didScrollToPosition(_:)`, `.viewDidLoad` or `queryTextFieldChangedTo(_:)`.
 - a `StateProvider`: that's the store output, so the system can subscribe a store for updates on State. Being a state provider basically means that store is an Observable<T>, where T is the State of your app, so an `UIViewController` can subscribe to state changes and react to them.

 The store will glue all the parts together and its responsibility is being a proxy to the non-Redux world. For that reason, it's correct to say that a `Store` is the single point of contact with `UIKit` and it's a class that you want to inject as a dependency on all the ViewControllers, either as one single dependency or, preferably, a dependency for each of its protocols - `EventHandler` and `StateProvider` -, both eventually pointing to the same instance.

[![ViewController and Store](https://swiftrex.github.io/SwiftRex/markdown/img/Redux1.gif)](https://www.youtube.com/watch?v=oBR94I2p2BA)

 In its documentation, Apple suggests some communication patterns between the MVC layers. Most important, they say that Controllers should update the Model, who notifies the Controller about changes:

 ![iOS MVC](https://swiftrex.github.io/SwiftRex/markdown/img/CocoaMVC.gif)

 You can think of Store as a very heavy "Model" layer, completely detached from the View and Controller, and where all the business logic stands. At a first sight it may look like transfering the "Massive" problem from a layer to another, but later in this docs it's gonna be clear how the logic will be split and, hopefully, by having specialized middlewares we can even start sharing more code between different apps or different devices such as Apple TV, macOS, iOS, watchOS or backend APIs, thanks to the business decisions being completely off your presentation layer.

 You want only one Store in your app, so either you create a singleton or a public property in a long-life class such as AppDelegate or AppCoordinator. That's crucial for making the store completely detached from the `UIKit` world. Theoretically it should be possible to keep multiple stores - one per module or per `UIViewController` - and keep them in sync through Rx observation, like the "Flux" approach. However, the main goal of SwiftRex is to keep an unified state independent from `UIKit`, therefore it's the recommended approach.

 The `StoreBase` implementation also is:
 - an `ActionHandler`: be able to receive and distribute actions of type `ActionProtocol`

 A `StoreBase` uses `Middleware` pipeline and `Reducer` pipeline. It creates a queue of incoming events that is handled to the middleware pipeline, which triggers actions back to the store. These actions are put in a queue that again are handled to the middleware pipeline, usually for logging or analytics purposes. The actions are them forwarded to the `Reducer` pipeline, together with the current state. One by one, the reducers will handle the action and incrementally change a copy of the app state. When this process is done, the store takes the resulting state, sets it as the current state and notifies all subscribers.

 ![Store internals](https://swiftrex.github.io/SwiftRex/markdown/img/StoreInternals.png)

## 🕹 EventProtocol

 `EventProtocol` represents an event, usually created in response to an user's input, such as tap, swipe, pinch, scroll.

 An `EventProtocol` is usually a request from your user to which the app should respond, for example the tab bar icon was tapped, a menu item was selected, a swipe gesture from left to right on cell number `3` or a new character was pressed in a search bar. Other events can be generated by other actors, such as timers or `CoreLocation` updates, but let's skip that for a moment and thing exclusively about the main actor of most use cases: the user. Because the user interaction is given mainly throughout an `UIViewController`, we should agree that View Controllers will create and dispatch most events to the `Store`, where the `Middleware` pipeline will handle it to decide whether or not act on each.

 `EventProtocol` is a marker protocol and usually you want to keep events as tiny value-type structures: struct or enum. Having associated values is completely optional, but please keep in mind that you should pass as minimum information as necessary, and avoid passing value that's already in the state.

 For example, if there's a table view showing a list of movies, for each cell you may have a "Mark as Watched" (or Unwatched) button and a "Show Details" button, while the navigation bar has a button to mark all as watched. In that case, event enum could be:

 ```swift
 enum MovieListEvent: EventProtocol {
     case didTapWatchToggle(rowIndex: Int)
     case didTapDetailsButton(rowIndex: Int)
     case didTapMarkAllAsWatched
 }
 ```

 Because your `State` already knows whether or not the movie was watched, you just need to offer a single "toggle" event instead of two events for watch or unwatch, and also there's no need for an extra boolean parameter. Moreover, you could pass the `IndexPath.row` instead of `movieId` so your enum becomes essentially a generic control event and your cells don't have to maintain IDs or any other model information.

## 🏄‍ ActionProtocol

`ActionProtocol` represents an action, usually created by a `Middleware` in response to an event.

Like events, `ActionProtocol` is also a marker protocol which concrete implementation is a value-type structure holding the associated value that is necessary to request a change in the state. Differently from events, although, actions have more meaningful values and are driven by business logic. While an `EventProtocol` represents taps in the interface and usually has associated values like `3` or `true`, an `ActionProtocol` is expected to hold the information required to mutate the state, such as: "got a new list of movies" with an associated values of `[Movie]`, or "delete invoice" and the associated value being the Invoice object. That way, we should not expect actions to be triggered by an `UIViewController`, only by a `Middleware` running in the `Store`. Some middlewares can create one or multiple actions out of an event, collecting the proper state information from the indexes passed with the event, and then finally composing a very meaningful action that contains exactly the metadata for the change.

An event may end up not changing the state, but an action necessarily implies that the state will be mutated accordingly; for example the event `viewDidLoad` may not change your state, having the only purpose of logging or tracking analytics events (let's talk about side-effects later), and in that case don't change anything in the app; while an action `userHasLoggedIn` will necessarily change something on the state.

```swift
enum MovieListAction: ActionProtocol {
    case setMovieAsWatched(movieId: UUID)
    case setMovieAsUnwatched(movieId: UUID)
    case setCurrentMovieDetailsPage(movie: Movie)
    case setMoviesAsWatched(movies: [Movie])
}
```

## ⛓ Middleware

`Middleware` is a plugin, or a composition of several plugins, that are assigned to the `Store` pipeline in order to handle each `EventProtocol` dispatched and to create `ActionProtocol` in response. It's also capable of handling each `ActionProtocol` before the `Reducer` to do its job.

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
- `RxSwift` observables / `ReactiveSwift` signal producers

## 🌍 SideEffectProducer

`SideEffectProducer` defines a protocol for implementing a `RxSwift` or `ReactiveSwift` side-effect producer, that will warms up a cold observation once it's executed. If your producer needs the `EventProtocol` that started the side-effect, you can pass it in the `SideEffectProducer` initializer and save it in a property. Please keep in mind that for every event, a new instance of a `SideEffectProducer` will be created, which means that every execution is completely isolated from each other and if you need to access a shared resource or cancel previous operations you must be careful implementing such things.

Some Middlewares are shipped with SwiftRex. While you're still welcome to create your own Middlewares from the scratch, some of the stock ones can offer you a shortcut. For RxSwift or ReactiveSwift users we bring a `SideEffectMiddleware` that is a quick way to reuse your existing Observable/SignalProducer pipelines. The Middleware requires the implementation of only one method:

```swift
func sideEffect(for event: Event) -> AnySideEffectProducer<StateType>?
```

Given an event, map it to a Side-Effect producer that handles such event. And what is a Side-Effect producer? It's a protocol with a single method to be implemented:

```swift
func execute(getState: @escaping GetState<StateType>) -> Observable<Action>
```

Given the current state (that can be checked consistently at any point), return an Observable sequence of `Action`. In your Rx pipeline you can trigger as many side-effects as you want, and every time an Action occurs you can easily notify the observer, that forwards it to the Store.

## ⚙ Reducer

`Reducer` is a pure function wrapped in a monoid container, that takes current state and an action to calculate the new state.

The `Middleware` pipeline can trigger `ActionProtocol`, and handles both `EventProtocol` and `ActionProtocol`. But what they can NOT do is changing the app state. Middlewares have read-only access to the up-to-date state of our apps, but when mutations are required we use the `Reducer` function. Actually, it's a protocol that requires only one method:

```swift
func reduce(_ currentState: StateType, action: Action) -> StateType
```

Given the current state and an action, returns the calculated state. This function will be executed in the last stage of an action handling, when all middlewares had the chance to modify or improve the action. Because a reduce function is composable monoid and also can be lifted through lenses, it's possible to write fine-grained "sub-reducer" that will handle only a "sub-state", creating a pipeline of reducers.

It's important to understand that reducer is a synchronous operations that calculates a new state without any kind of side-effect, so never add properties to the `Reducer` structs or call any external function. If you are tempted to do that, please create a middleware. Reducers are also responsible for keeping the consistency of a state, so it's always good to do a final sanity check before changing the state.

Once the reducer function executes, the store will update its single source of truth with the new calculated state, and propagate it to all its observers.