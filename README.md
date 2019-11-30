<p align="center">
	<a href="https://github.com/SwiftRex/SwiftRex/"><img src="https://swiftrex.github.io/SwiftRex/markdown/img/SwiftRexBanner.png" alt="SwiftRex" /></a><br /><br />
	Unidirectional Dataflow for your favourite reactive framework<br /><br />
</p>

[![Build Status](https://api.travis-ci.org/SwiftRex/SwiftRex.svg?branch=develop&maxAge=600)](https://travis-ci.org/SwiftRex/SwiftRex)
[![Coverage Status](https://img.shields.io/coveralls/github/SwiftRex/SwiftRex/develop.svg)](https://coveralls.io/github/SwiftRex/SwiftRex?branch=develop)
[![Jazzy Documentation](https://swiftrex.github.io/SwiftRex/api/badge.svg)](https://swiftrex.github.io/SwiftRex/api/index.html)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-orange.svg)](https://github.com/Carthage/Carthage)
[![CocoaPods compatible](https://img.shields.io/cocoapods/v/SwiftRex.svg)](https://cocoapods.org/pods/SwiftRex)
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-orange.svg)](https://github.com/apple/swift-package-manager)
![Swift](https://img.shields.io/badge/Swift-5.1-orange.svg)
[![Platform support](https://img.shields.io/badge/platform-iOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20macOS-252532.svg)](https://github.com/SwiftRex/SwiftRex)
[![License Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/SwiftRex/SwiftRex/blob/master/LICENSE)

# Introduction

SwiftRex is a framework that combines Unidirectional Dataflow architecture and reactive programming ([Combine](https://developer.apple.com/documentation/combine), [RxSwift](https://github.com/ReactiveX/RxSwift) or [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift)), providing a central state Store for the whole state of your app, of which your SwiftUI Views or UIViewControllers can observe and react to, as well as dispatching events coming from the user interactions.

This pattern, also known as ["Redux"](https://redux.js.org/basics/data-flow), allows us to rethink our app as a single [pure function](https://en.wikipedia.org/wiki/Pure_function) that receives user events as input and returns UI changes in response. The benefits of this workflow will hopefully become clear soon.

[API documentation can be found here](https://swiftrex.github.io/SwiftRex/api/index.html).

# Goals

Several architectures and design patterns for mobile development nowadays propose to solve specific issues related to [Single Responsibility Principle](https://www.youtube.com/watch?v=Gt0M_OHKhQE) (such as Massive ViewControllers), or improve testability and dependency management. Other common challenges for mobile developers such as handling state, race conditions, thread-safety or dealing properly with UI life-cycle and ownership are less explored but can be equally harmful for an app.

Managing all of these problems may sound like an impossible task that would require lots of patterns and really complex test scenarios. After all, how to to reproduce a rare but critical error that happens only with some of your users but never in developers' equipment? This can be frustrating and most of us has probably faced such problems from time to time.

That's the scenario where SwiftRex shines, because it:
<details>
    <summary>enforces the application of Single Responsibility Principle</summary>
    <p>Some architectures are very flexible and allow us to add any piece of code anywhere. This should be fine for most small apps developed by only one person, but once the project and the team start to grow, some layers will get really large, holding too much responsibility, implicit side-effects, race conditions and other bugs. In this scenario, testability is also damaged, as is consistency between different parts of the app, so finding and fixing bugs becomes really tricky.</p>
    <p>SwiftRex prevents that by having a very strict policy of where the code should be and how limited that layer is, policy that is often enforced by the compiler. Well, this sounds hard and complicated, but in fact it's easier than traditional patterns, because once you understand this architecture you know exactly what to do, you know exactly where to find some line of code based on its responsibility, you know exactly how to test each component and you understand very well what are the boundaries of each layer.</p>
</details>
<details>
    <summary>offers a clear test strategy for each layer</summary>
    <p>We believe that an architecture must not only be very testable, but also offer a clear guideline of how to test each of its layers. If a layer has only one job, and this job can be verified by assertions of expected outputs based on given input all the times, the tests can be more meaningful and broad, so no regressions are introduced when a new feature is created.</p>
    <p>Most layers in SwiftRex architecture will be pure functions, that means all its computation is done solely from the input parameters, and all its results will be exposed on the output, no implicit effect or access to global scope. Testing that won't require mocks, stubs, dependency injection or any kind of preparation, you call a function with a value, you check the result and that's it.</p>
    <p>This is true for the UI Layer, presentation layer, reducers and state publishers, because this whole chain is a composition of pure functions. The only layer that needs dependency injection, therefore mocks, is the middleware, once it's the only layer that depends on services and triggers side-effects to the outside world. Luckily because middlewares are composable, we can break them into very small pieces that do only one job, and testing that becomes more pleasant and easy, because instead of mocking hundreds of components you only have to inject one.</p>
</details>
<details>
    <summary>isolates all the side-effects in composable/reusable middleware boxes that can't mutate the state</summary>
    <p>If a layer has to handle multiple services at the same time and mutate the state as they asynchronously respond, it's hard to keep this state consistent and prevent race conditions. It's also harder to test because one effect can interfere in the other.</p>
    <p>Along the years, both Apple and the community created amazing frameworks to access services in the web or network and sensors in the device. Unfortunately some of these frameworks rely on delegate pattern, some use closures/callbacks, some use Notification Center, KVO or reactive streams. Composing this mixture of notification forms will require boolean flags, counters, and other implicit state that will eventually break due to race conditions.</p>
    <p>Reactive frameworks help to make this more uniform and composable, especially when used together with their Cocoa extensions, and in fact even Apple realised that and a significant part of WWDC 2019 was focused on demonstrating and fixing this problem, with the help of newly introduced frameworks Combine and SwiftUI.</p>
    <p>But composing lots of services in reactive pipelines is not always easy and has its own pitfalls, like full pipeline cancellation because one stream emitted an error, event reentrancy and, last but not least, steep learning curve on mastering the several operators.</p>
    <p>SwiftRex uses reactive-programming a lot, and allows you to use it as much as you feel comfortable. However we also offer a more uniform way to compose different services with only 1 data type and 2 operators: middleware, `<>` operator and `liff` operator, all the other operations can be simplified by triggering actions to itself, other middlewares or state reducers. You still have the option to create a larger middleware and handle multiple sources in a traditional reactive-stream fashion, if you like, but this can be overwhelming for un-experienced developers, harder to test and harder to reuse in different apps.</p>
    <p>Because this topic is very wide it's going to be better explained in the Middleware documentation.</p>
</details>
<details>
    <summary>minimizes the usage of dependencies on ViewControllers/Presenters/Interactors/SwiftUI Views</summary>
    <p>Passing dependencies as you browse your app was never an easy task: ViewControllers initialisers are very tricky, you must always consider when the class is being created from NIB/XIB, programmatically or storyboards, then write the correct init method passing not only all the dependencies this class needs, but also the dependencies needed by its child view controllers and the next view controller that will be pushed when you press a button, so you have to keep sending dozens of dependencies across your views while routing through them. If initialisers are not used but property assignment is preferred, these properties have to be implicit unwrapped, which is not great.</p>
    <p>Surely coordinator/wireframe patterns help on that, but somehow you transfer the problems to the routers, that also need to keep asking more dependencies that they actually use, but because the next router will use. You can use a service locator pattern, such as the popular <a href="https://vimeo.com/291588126">Environment</a> approach, and this is really an easy way to handle the problem. Testing this singleton, however, can be tricky, because, well, it's a singleton. Also some people don't like the implicit injection and feel more comfortable adding the explicit dependencies a layer needs.</p>
    <p>So it's impossible to solve this and make everybody happy, right? Well, not really. What if your view controllers only need a single dependency called "Store", from where it gets the state it needs and to where it dispatches all user events without actually executing any work? In this case, injecting the store is much easier regardless if you use explicit injection or service locator.</p>
    <p>Ok, but someone still has to do the work, and this is precisely the job that middlewares execute. In SwiftRex, middlewares should be created in entry-point of an app, right after the dependencies are configured and ready. Then you create all middlewares, injecting whatever they need to perform their work (hopefully not more than 2 dependencies per middleware, so you know they are not holding too many responsibilities). Finally you compose them and start your store. Middlewares can have timers or purely react to actions coming from the UI, but they are the only layer that has side-effects, therefore the only layer that needs services dependencies.</p>
    <p>Finally, you can add locale, language and interface traits into your global state, so even if you need to create number and date formatters in your state you still can do it without dependency injection, and even better, react properly when the user decides to change an iOS setting.</p>
</details>
<details>
    <summary>detaches state, services, mutation and other side-effects completely from the UI life-cycle and its ownership tree</summary>
    <p>UIViewControllers have a very peculiar ownership model: you don't control it. The view controllers are kept in memory while they are in the navigation stack, or if a tab is presented, or while a modal view is shown, but they can be released at any point, and with it, anything you put the ownership under view controller umbrella. All those [weak self] we've been using and loving can actually be weak sometimes, and it's very easy to not reason about that when we "guard that else return". Any important task that MUST be completed, regardless of your view being shown or not, should not be under the view controller life-cycle, as the user can easily dismiss your modal or pop your view. SwiftUI that has improved that but it's still possible to start async tasks from views' closures, and although now that view is a value-type it's a bit harder to make those mistakes, it's still possible.</p>
    <p>SwiftRex solves this problem by enforcing that all and every side-effect or async task should be done by the middleware, not the views. And middleware life-cycle is owned by the store, so we shouldn't expect any unfortunate surprise as long as the store lives while the app lives.</p>
    <p>For more information <a href="docs/markdown/UIKitLifetimeManagement.md">please check this link</a></p>
</details>
<details>
    <summary>eliminates race conditions</summary>
    <p>When an app has to deal with information coming from different services and sources it's common the need for small boolean flags here and there to check when something has completed or failed. Usually this is due to the fact that some services report back via delegates, some via closures, and several other creative ways. Synchronising these multiple sources by using flags, or mutating the same variables or array from concurrent tasks can lead to really strange bugs and crashes, usually the most difficult sort of bugs to catch, understand and fix.</p>
    <p>Dealing with locks and dispatch queues can help on that, but doing this over and over again in a ad-hoc manner is tedious and dangerous, tests must be written that consider all possible paths and timings, and some of these tests will eventually become flaky in case the race condition still exists.</p>
    <p>By enforcing all events of the app to go through the same queue which, by the end, mutates uniformly the global state in a consistent manner, SwiftRex will prevent race conditions. First because having middlewares as the only source of side-effects and async tasks will simplify testing for race conditions, especially if you keep them small and focused on a single task. In that case, your responses will come in a queue following a FIFO order and will be handled by all the reducers at once. Second because the reducers are the gatekeepers for state mutation, keeping them free of side-effects is crucial to have a successful and consistent mutation.</p>
</details>
<details>
    <summary>allows a more type-safe coding style</summary>
    <p>Swift generics are a bit hard to learn, and also are protocols associated types. SwiftRex doesn't require that you master generics, understand covariance or type-erasure, but more you dive into this world certainly you will write apps that are validated by the compiler and not by unit-tests. Bringing bugs from the runtime to the compile time is a very important goal that we all should embrace as good developers. It's probably better to struggle Swift type system (and sometimes SourceKit crashes) than checking crash-reports after your app was released to the wild. This is exactly the mindset Swift brought as a static-typed language, a language where even nullability is type-safe, and thanks to Optional<Wrapped> we can now rest peacefully knowing that we won't access null pointers unless we unsafely - and explicitly - choose that.</p>
    <p>SwiftRex enforces the use of strongly-typed events/actions and state everywhere: store's action dispatcher, middleware's action handler, middleware's action output, reducer's actions and states inputs and output and finally store's state observation, the whole flow is strongly-typed so the compiler can prevent mistakes or runtime bugs.</p>
    <p>Furthermore, Middlewares, Reducers and Store all can be "lifted" from a partial state and action to a global state and action. What does that mean? It means that you can write a strongly-typed module that operates in an specific domain, like network reachability. Your middleware and reducer will "speak" network domain state and actions, things like it's connected or not, it's wi-fi or LTE, did change connectivity action, etc. Then you can "lift" these two components - middleware and reducer - to a global state of your app, by providing two map functions: one for lifting the state and the other for lifting the action. Thanks to generics, this whole operation is completely type-safe. The same can be done by "deriving" a store projection from the main store. A store projection implements the two methods that a Store must have (input action and output state), but instead of being a real store it only projects the global state and actions into more localised domain, that means, view events translated to actions and view state translated to domain state.</p>
    <p>With these tools we believe you can write, if you want, an app that is type-safe from edge to edge.</p>
</details>
<details>
    <summary>helps to achieve modularity and code reuse between projects</summary>
    <p>Middlewares should be focused in a very very small domain, performing only one type of work and reporting back in form of actions. Reducers should be focused in a very tiny combination of action and state. Views should have access to a really tiny portion of the state, or ideally to a view state that is a flat representation of the app global state using primitives that map directly to text field's string, toggle's boolean, progress bar's double from 0.0 to 1.0 and so on and so forth.</p>
    <p>Then, you can "lift" these three pieces - middleware, reducer, store projection - into the global state and action your app actually needs.</p>
    <p>SwiftRex allows us to create small units-of-work that can be lifted to a global domain only when needed, so we can have Swift frameworks operating in a very specific domain, and covered with tests and Playgrounds/SwiftUI Previews to be used without having to launch the full app. Once this framework is ready, we just plug in our app, or even better, apps. Focusing on small domains will unlock better abstractions, and when this goes from middlewares (side-effect) to views, you have a powerful tool to define your building blocks.</p>
</details>
<details>
    <summary>offers a proper state management</summary>
    <p>A trustable truth that will never be inconsistent or out of sync among screens is possible with SwiftRex. It can be scary to think all your state is in a single place, a single tree that holds everything. It can be scary to see how much state you need, once you gather everything in a single place. But worry not, this is nothing that you didn't have before, it was there already, in a ViewController, in a Presenter, in a flag used to control the result of a service, but because it was so spread you didn't see how big it was. And worse, this leads to duplication, because when you need the same information from two different places, it's easier to duplicate and hope that you'll keep them in sync properly.</p>
    <p>In fact, when you gather your whole app state in a unified tree, you start getting rid of lots of things you don't need any more and your final state will be smaller than the messy one.</p>
    <p>Writing the global state and the global action tree correctly can be challenging, but this is the app domain and reasoning about that is probably the most important task an engineer has to do.</p>
    <p>For more information <a href="docs/markdown/StateManagement.md">please check this link</a></p>
</details>

I'm not gonna lie, it's a completely different way of writing apps, as most reactive approaches are; but once you get used to, it makes more sense and enables you to reuse much more code between your projects, gives you better tooling for writing software, testing, debugging, logging and finally thinking about events, state and mutation as you've never done before. And I promise you, it's gonna be a way with no return, an Unidirectional journey.

# Installation

## CocoaPods

TBD
         
## Swift Package Manager

TBD

## Carthage

TBD

# Core Parts
- [Store](#-store)
- [Action](#-action)
- [Middleware](#-middleware)
- [Reducer](#-reducer)

## Store

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

## Action

TBD

## Middleware

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
- `Combine` publishers/subjects, `RxSwift` observables / `ReactiveSwift` signal producers

## Reducer

`Reducer` is a pure function wrapped in a monoid container, that takes current state and an action to calculate the new state.

The `Middleware` pipeline can trigger `ActionProtocol`, and handles both `EventProtocol` and `ActionProtocol`. But what they can NOT do is changing the app state. Middlewares have read-only access to the up-to-date state of our apps, but when mutations are required we use the `Reducer` function. Actually, it's a protocol that requires only one method:

```swift
func reduce(_ currentState: StateType, action: Action) -> StateType
```

Given the current state and an action, returns the calculated state. This function will be executed in the last stage of an action handling, when all middlewares had the chance to modify or improve the action. Because a reduce function is composable monoid and also can be lifted through lenses, it's possible to write fine-grained "sub-reducer" that will handle only a "sub-state", creating a pipeline of reducers.

It's important to understand that reducer is a synchronous operations that calculates a new state without any kind of side-effect, so never add properties to the `Reducer` structs or call any external function. If you are tempted to do that, please create a middleware. Reducers are also responsible for keeping the consistency of a state, so it's always good to do a final sanity check before changing the state.

Once the reducer function executes, the store will update its single source of truth with the new calculated state, and propagate it to all its observers.

# Projection and Lifting
- [Store Projection](#-storeprojection)
- [LiftMiddleware](#-liftmiddleware)
- [LiftReducer](#-liftreducer)

## Store Projection

TBD

![Store Projection](https://swiftrex.github.io/SwiftRex/markdown/img/StoreProjectionDiagram.png)

## LiftMiddleware

TBD

## LiftReducer

TBD
