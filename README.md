<p align="center">
	<a href="https://github.com/SwiftRex/SwiftRex/"><img src="https://swiftrex.github.io/SwiftRex/markdown/img/SwiftRexBanner.png" alt="SwiftRex" /></a><br /><br />
	Unidirectional Dataflow for your favourite reactive framework<br /><br />
</p>

[![Build Status](https://travis-ci.org/SwiftRex/SwiftRex.svg?branch=develop)](https://travis-ci.org/SwiftRex/SwiftRex)
[![codecov](https://codecov.io/gh/SwiftRex/SwiftRex/branch/develop/graph/badge.svg)](https://codecov.io/gh/SwiftRex/SwiftRex)
[![Jazzy Documentation](https://swiftrex.github.io/SwiftRex/api/badge.svg)](https://swiftrex.github.io/SwiftRex/api/index.html)
[![CocoaPods compatible](https://img.shields.io/cocoapods/v/SwiftRex.svg)](https://cocoapods.org/pods/SwiftRex)
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-orange.svg)](https://swiftpackageindex.com/SwiftRex/SwiftRex)
![Swift](https://img.shields.io/badge/Swift-5.3-orange.svg)
[![Platform support](https://img.shields.io/badge/platform-iOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20macOS%20%7C%20Catalyst-252532.svg)](https://github.com/SwiftRex/SwiftRex)
[![License Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/SwiftRex/SwiftRex/blob/master/LICENSE)

# Introduction

SwiftRex is a framework that combines Unidirectional Dataflow architecture and reactive programming ([Combine](https://developer.apple.com/documentation/combine), [RxSwift](https://github.com/ReactiveX/RxSwift) or [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift)), providing a central state Store for the whole state of your app, of which your SwiftUI Views or UIViewControllers can observe and react to, as well as dispatching events coming from the user interactions.

This pattern, also known as ["Redux"](https://redux.js.org/basics/data-flow), allows us to rethink our app as a single [pure function](https://en.wikipedia.org/wiki/Pure_function) that receives user events as input and returns UI changes in response. The benefits of this workflow will hopefully become clear soon.

[API documentation can be found here](https://swiftrex.github.io/SwiftRex/api/index.html).

# Quick Guide

In a hurry? Already familiar with other redux implementations?

No problem, we have a [TL;DR Quick Guide](docs/markdown/QuickGuide.md) that shows the minimum you need to know about SwiftRex in a very practical approach.

We still recommend reading the full README for a deeper understanding behind SwiftRex concepts.

# Goals

Several architectures and design patterns for mobile development nowadays propose to solve specific issues related to [Single Responsibility Principle](https://www.youtube.com/watch?v=Gt0M_OHKhQE) (such as Massive ViewControllers), or improve testability and dependency management. Other common challenges for mobile developers such as state handling, race conditions, modularization/componentization, thread-safety or dealing properly with UI life-cycle and ownership are less explored but can be equally harmful for an app.

Managing all of these problems may sound like an impossible task that would require lots of patterns and really complex test scenarios. After all, how to to reproduce a rare but critical error that happens only with some of your users but never in developers' equipment? This can be frustrating and most of us has probably faced such problems from time to time.

That's the scenario where SwiftRex shines, because it:
<details>
    <summary>enforces the application of Single Responsibility Principle [tap to expand]</summary>
    <p>Some architectures are very flexible and allow us to add any piece of code anywhere. This should be fine for most small apps developed by only one person, but once the project and the team start to grow, some layers will get really large, holding too much responsibility, implicit side-effects, race conditions and other bugs. In this scenario, testability is also damaged, as is consistency between different parts of the app, so finding and fixing bugs becomes really tricky.</p>
    <p>SwiftRex prevents that by having a very strict policy of where the code should be and how limited that layer is, policy that is often enforced by the compiler. Well, this sounds hard and complicated, but in fact it's easier than traditional patterns, because once you understand this architecture you know exactly what to do, you know exactly where to find some line of code based on its responsibility, you know exactly how to test each component and you understand very well what are the boundaries of each layer.</p>
</details>
<details>
    <summary>offers a clear test strategy for each layer (<a href="https://github.com/SwiftRex/TestingExtensions">also check TestingExtensions</a>) [tap to expand]</summary>
    <p>We believe that an architecture must not only be very testable, but also offer a clear guideline of how to test each of its layers. If a layer has only one job, and this job can be verified by assertions of expected outputs based on given input all the times, the tests can be more meaningful and broad, so no regressions are introduced when a new feature is created.</p>
    <p>Most layers in SwiftRex architecture will be pure functions, that means all its computation is done solely from the input parameters, and all its results will be exposed on the output, no implicit effect or access to global scope. Testing that won't require mocks, stubs, dependency injection or any kind of preparation, you call a function with a value, you check the result and that's it.</p>
    <p>This is true for the UI Layer, presentation layer, reducers and state publishers, because this whole chain is a composition of pure functions. The only layer that needs dependency injection, therefore mocks, is the middleware, once it's the only layer that depends on services and triggers side-effects to the outside world. Luckily because middlewares are composable, we can break them into very small pieces that do only one job, and testing that becomes more pleasant and easy, because instead of mocking hundreds of components you only have to inject one.</p>
    <p>We also offer <a href="https://github.com/SwiftRex/TestingExtensions">TestingExtensions</a> that allows us to test the whole use case using a DSL syntax that will validate all SwiftRex layers, ensuring that no unexpected side-effect or action happened, and the state was mutated step-by-step as expected. This is a powerful and fun way to test the whole app with few and easy-to-write lines.</p>
</details>
<details>
    <summary>isolates all the side-effects in composable/reusable middleware boxes that can't mutate the state [tap to expand]</summary>
    <p>If a layer has to handle multiple services at the same time and mutate the state as they asynchronously respond, it's hard to keep this state consistent and prevent race conditions. It's also harder to test because one effect can interfere in the other.</p>
    <p>Along the years, both Apple and the community created amazing frameworks to access services in the web or network and sensors in the device. Unfortunately some of these frameworks rely on delegate pattern, some use closures/callbacks, some use Notification Center, KVO or reactive streams. Composing this mixture of notification forms will require boolean flags, counters, and other implicit state that will eventually break due to race conditions.</p>
    <p>Reactive frameworks help to make this more uniform and composable, especially when used together with their Cocoa extensions, and in fact even Apple realised that and a significant part of <a href="https://developer.apple.com/videos/play/wwdc2019/226/">WWDC 2019</a> was focused on demonstrating and fixing this problem, with the help of newly introduced frameworks Combine and SwiftUI.</p>
    <p>But composing lots of services in reactive pipelines is not always easy and has its own pitfalls, like full pipeline cancellation because one stream emitted an error, event reentrancy and, last but not least, steep learning curve on mastering the several operators.</p>
    <p>SwiftRex uses reactive-programming a lot, and allows you to use it as much as you feel comfortable. However we also offer a more uniform way to compose different services with only 1 data type and 2 operators: middleware, `<>` operator and `lift` operator, all the other operations can be simplified by triggering actions to itself, other middlewares or state reducers. You still have the option to create a larger middleware and handle multiple sources in a traditional reactive-stream fashion, if you like, but this can be overwhelming for un-experienced developers, harder to test and harder to reuse in different apps.</p>
    <p>Because this topic is very wide it's going to be better explained in the Middleware documentation.</p>
</details>
<details>
    <summary>minimizes the usage of dependencies on ViewControllers/Presenters/Interactors/SwiftUI Views [tap to expand]</summary>
    <p>Passing dependencies as you browse your app was never an easy task: ViewControllers initialisers are very tricky, you must always consider when the class is being created from NIB/XIB, programmatically or storyboards, then write the correct init method passing not only all the dependencies this class needs, but also the dependencies needed by its child view controllers and the next view controller that will be pushed when you press a button, so you have to keep sending dozens of dependencies across your views while routing through them. If initialisers are not used but property assignment is preferred, these properties have to be implicit unwrapped, which is not great.</p>
    <p>Surely coordinator/wireframe patterns help on that, but somehow you transfer the problems to the routers, that also need to keep asking more dependencies that they actually use, but because the next router will use. You can use a service locator pattern, such as the popular <a href="https://vimeo.com/291588126">Environment</a> approach, and this is really an easy way to handle the problem. Testing this singleton, however, can be tricky, because, well, it's a singleton. Also some people don't like the implicit injection and feel more comfortable adding the explicit dependencies a layer needs.</p>
    <p>So it's impossible to solve this and make everybody happy, right? Well, not really. What if your view controllers only need a single dependency called "Store", from where it gets the state it needs and to where it dispatches all user events without actually executing any work? In this case, injecting the store is much easier regardless if you use explicit injection or service locator.</p>
    <p>Ok, but someone still has to do the work, and this is precisely the job that middlewares execute. In SwiftRex, middlewares should be created in entry-point of an app, right after the dependencies are configured and ready. Then you create all middlewares, injecting whatever they need to perform their work (hopefully not more than 2 dependencies per middleware, so you know they are not holding too many responsibilities). Finally you compose them and start your store. Middlewares can have timers or purely react to actions coming from the UI, but they are the only layer that has side-effects, therefore the only layer that needs services dependencies.</p>
    <p>Finally, you can add locale, language and interface traits into your global state, so even if you need to create number and date formatters in your state you still can do it without dependency injection, and even better, react properly when the user decides to change an iOS setting.</p>
</details>
<details>
    <summary>detaches state, services, mutation and other side-effects completely from the UI life-cycle and its ownership tree [tap to expand]</summary>
    <p>UIViewControllers have a very peculiar ownership model: you don't control it. The view controllers are kept in memory while they are in the navigation stack, or if a tab is presented, or while a modal view is shown, but they can be released at any point, and with it, anything you put the ownership under view controller umbrella. All those [weak self] we've been using and loving can actually be weak sometimes, and it's very easy to not reason about that when we "guard that else return". Any important task that MUST be completed, regardless of your view being shown or not, should not be under the view controller life-cycle, as the user can easily dismiss your modal or pop your view. SwiftUI that has improved that but it's still possible to start async tasks from views' closures, and although now that view is a value-type it's a bit harder to make those mistakes, it's still possible.</p>
    <p>SwiftRex solves this problem by enforcing that all and every side-effect or async task should be done by the middleware, not the views. And middleware life-cycle is owned by the store, so we shouldn't expect any unfortunate surprise as long as the store lives while the app lives.</p>
    <p>You still can dispatch "viewDidLoad", "onAppear", "onDisappear" events from your views, in order to perform task cancellations, so you gain more control, not less.</>
    <p>For more information <a href="docs/markdown/UIKitLifetimeManagement.md">please check this link</a></p>
</details>
<details>
    <summary>eliminates race conditions [tap to expand]</summary>
    <p>When an app has to deal with information coming from different services and sources it's common the need for small boolean flags here and there to check when something has completed or failed. Usually this is due to the fact that some services report back via delegates, some via closures, and several other creative ways. Synchronising these multiple sources by using flags, or mutating the same variables or array from concurrent tasks can lead to really strange bugs and crashes, usually the most difficult sort of bugs to catch, understand and fix.</p>
    <p>Dealing with locks and dispatch queues can help on that, but doing this over and over again in a ad-hoc manner is tedious and dangerous, tests must be written that consider all possible paths and timings, and some of these tests will eventually become flaky in case the race condition still exists.</p>
    <p>By enforcing all events of the app to go through the same queue which, by the end, mutates uniformly the global state in a consistent manner, SwiftRex will prevent race conditions. First because having middlewares as the only source of side-effects and async tasks will simplify testing for race conditions, especially if you keep them small and focused on a single task. In that case, your responses will come in a queue following a FIFO order and will be handled by all the reducers at once. Second because the reducers are the gatekeepers for state mutation, keeping them free of side-effects is crucial to have a successful and consistent mutation. Last but not least, everything happens in response to actions, and actions can be easily logged in or put in your crash reports, including who dispatched that action, so if you still find a race condition happening you can easily understand what actions are mutating the state and where these actions come from.</p>
</details>
<details>
    <summary>allows a more type-safe coding style [tap to expand]</summary>
    <p>Swift generics are a bit hard to learn, and also are protocols associated types. SwiftRex doesn't require that you master generics, understand covariance or type-erasure, but more you dive into this world certainly you will write apps that are validated by the compiler and not by unit-tests. Bringing bugs from the runtime to the compile time is a very important goal that we all should embrace as good developers. It's probably better to struggle Swift type system than checking crash-reports after your app was released to the wild. This is exactly the mindset Swift brought as a static-typed language, a language where even nullability is type-safe, and thanks to Optional<Wrapped> we can now rest peacefully knowing that we won't access null pointers unless we unsafely - and explicitly - choose that.</p>
    <p>SwiftRex enforces the use of strongly-typed events/actions and state everywhere: store's action dispatcher, middleware's action handler, middleware's action output, reducer's actions and states inputs and outputs and finally store's state observation, the whole flow is strongly-typed so the compiler can prevent mistakes or runtime bugs.</p>
    <p>Furthermore, Middlewares, Reducers and Store all can be "lifted" from a partial state and action to a global state and action. What does that mean? It means that you can write a strongly-typed module that operates in an specific domain, like network reachability. Your middleware and reducer will "speak" network domain state and actions, things like it's connected or not, it's wi-fi or LTE, did change connectivity action, etc. Then you can "lift" these two components - middleware and reducer - to a global state of your app, by providing two map functions: one for lifting the state and the other for lifting the action. Thanks to generics, this whole operation is completely type-safe. The same can be done by "deriving" a store projection from the main store. A store projection implements the two methods that a Store must have (input action and output state), but instead of being a real store it only projects the global state and actions into more localised domain, that means, view events translated to actions and view state translated to domain state.</p>
    <p>With these tools we believe you can write, if you want, an app that is type-safe from edge to edge.</p>
</details>
<details>
    <summary>helps to achieve modularity, componentization and code reuse between projects [tap to expand]</summary>
    <p>Middlewares should be focused in a very very small domain, performing only one type of work and reporting back in form of actions. Reducers should be focused in a very tiny combination of action and state. Views should have access to a really tiny portion of the state, or ideally to a view state that is a flat representation of the app global state using primitives that map directly to text field's string, toggle's boolean, progress bar's double from 0.0 to 1.0 and so on and so forth.</p>
    <p>Then, you can "lift" these three pieces - middleware, reducer, store projection - into the global state and action your app actually needs.</p>
    <p>SwiftRex allows us to create small units-of-work that can be lifted to a global domain only when needed, so we can have Swift frameworks operating in a very specific domain, and covered with tests and Playgrounds/SwiftUI Previews to be used without having to launch the full app. Once this framework is ready, we just plug in our app, or even better, apps. Focusing on small domains will unlock better abstractions, and when this goes from middlewares (side-effect) to views, you have a powerful tool to define your building blocks.</p>
</details>
<details>
    <summary>enforces single source of truth and proper state management [tap to expand]</summary>
    <p>A trustable single source of truth that will never be inconsistent or out of sync among screens is possible with SwiftRex. It can be scary to think all your state is in a single place, a single tree that holds everything. It can be scary to see how much state you need, once you gather everything in a single place. But worry not, this is nothing that you didn't have before, it was there already, in a ViewController, in a Presenter, in a flag used to control the result of a service, but because it was so spread you didn't see how big it was. And worse, this leads to duplication, because when you need the same information from two different places, it's easier to duplicate and hope that you'll keep them in sync properly.</p>
    <p>In fact, when you gather your whole app state in a unified tree, you start getting rid of lots of things you don't need any more and your final state will be smaller than the messy one.</p>
    <p>Writing the global state and the global action tree correctly can be challenging, but this is the app domain and reasoning about that is probably the most important task an engineer has to do.</p>
    <p>For more information <a href="docs/markdown/StateManagement.md">please check this link</a></p>
</details>
<details>
  <summary>offers tooling for development, tests and debugging [tap to expand]</summary>
  <p>Several projects offer SwiftRex tools to help developers when writing apps, tests, debugging it or evaluating crash reports.</p>
  <p><a href="https://github.com/SwiftRex/CombineRextensions">CombineRextensions</a> offers SwiftUI extensions to work with CombineRex, <a href="https://github.com/SwiftRex/TestingExtensions">TestingExtensions</a> has "test asserts" that will unlock testability of use cases in a fun and easy way, <a href="https://github.com/SwiftRex/InstrumentationMiddleware">InstrumentationMiddleware</a> allows you to use Instruments to see what's happening in a SwiftRex app, <a href="https://github.com/SwiftRex/SwiftRexMonitor">SwiftRexMonitor</a> will be a Swift version of well-known Redux DevTools where you can remotely monitor state and actions of an app from an external Mac or iOS device, and even inject actions to simulate side-effects (useful for UITests, for example), <a href="https://github.com/SwiftRex/GatedMiddleware">GatedMiddleware</a> is a middleware wrapper that can be used to enable or disable other middlewares in runtime, <a href="https://github.com/SwiftRex/LoggerMiddleware">LoggerMiddleware</a> is a very powerful logger to be used by developers to easily understand what's happening in runtime. More Middlewares will be open-sourced soon allowing, for example, to create good Crashlytics reports that tell the story of a crash as you've never had access before, and that way, recreate crashes or user reports. Also tools for generating code (Sourcery templates, Xcode snippets and templates, console tools), and also higher level APIs such as EffectMiddlewares that allow us to create Middlewares with a single function, as easy as Reducers are, or Handler that will allow to group Middlewares and Reducers under a same structure to be able to lift both together. New dependency injection strategies are about to be released as well.</p>
  <p>All these tools are already done and will be released any time soon, and more are expected for the future.</p>
</details>

I'm not gonna lie, it's a completely different way of writing apps, as most reactive approaches are; but once you get used to, it makes more sense and enables you to reuse much more code between your projects, gives you better tooling for writing software, testing, debugging, logging and finally thinking about events, state and mutation as you've never done before. And I promise you, it's gonna be a way with no return, an Unidirectional journey.

# Reactive Framework Libraries
SwiftRex currently supports the 3 major reactive frameworks:
- [Apple Combine](https://developer.apple.com/documentation/combine)
- [RxSwift](https://github.com/ReactiveX/RxSwift)
- [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift)

More can be easily added later by implementing some abstraction bridges that can be found in the `ReactiveWrappers.swift` file. To avoid adding unnecessary files to your app, SwiftRex is split in 4 packages:
- SwiftRex: the core library
- CombineRex: the implementation for Combine framework
- RxSwiftRex: the implementation for RxSwift framework
- ReactiveSwiftRex: the implementation for ReactiveSwift framework

SwiftRex itself won't be enough, so you have to pick one of the three implementations.

# Parts

Let's understand the components of SwiftRex by splitting them into 3 sections:
- [Conceptual parts](#conceptual-parts)
    - [Action](#action)
    - [State](#state)
- [Core Parts](#core-parts)
    - [Store](#store)
    - [Middleware](#middleware)
        - [EffectMiddleware](#effectmiddleware)
    - [Reducer](#reducer)
- [Projection and Lifting](#projection-and-lifting)
    - [Store Projection](#store-projection)
    - [Lifting Middleware](#lifting-middleware)
    - [Lifting Reducer](#lifting-reducer)

---
## Conceptual Parts
- [Action](#action)
- [State](#state)
---
### Action

There's no "Action" protocol or type in SwiftRex. However, Action will be found as a generic parameter for most core data structures, meaning that it's up to you to define what is the root Action type.

Conceptually, we can say that an Action represents something that happens from external actors of your app, that means user interactions, timer callbacks, responses from web services, callbacks from CoreLocation and other frameworks. Some internal actors also can start actions, however. For example, when UIKit finishes loading your view we could say that `viewDidLoad` is an action, in case we're interested in this event. Same for SwiftUI View (`.onAppear`, `.onDisappear`, `.onTap`) or Gesture (`.onEnded`, `.onChanged`, `.updating`) modifiers, they all can be considered actions. When URLSession replies with a Data that we were able to parse into a struct, this can be a successful action, but when the response is a 404, or JSONDecoder can't understand the payload, this should also become a failure Action. NotificationCenter does nothing else but notifying actions from all over the system, such as keyboard dismissal or device rotation. CoreData and other realtime databases have mechanism to notify when something changed, and this should become an action as well.

**Actions are about INPUT events that are relevant for an app.**

For representing an action in your app you can use structs, classes or enums, and organize the list of possible actions the way you think it's better. But we have a recommended way that will enable you to fully use type-safety and avoid problems, and this way is by using a tree structure created with enums and associated values.

```swift
enum AppAction {
    case started
    case movie(MovieAction)
    case cast(CastAction)
}

enum MovieAction {
    case requestMovieList
    case gotMovieList(movies: [Movie])
    case movieListResponseError(MovieResponseError)
    case selectMovie(id: UUID)
}

enum CastAction {
    case requestCastList(movieId: UUID)
    case gotCastList(movieId: UUID, cast: [Person])
    case castListResponseError(CastResponseError)
    case selectPerson(id: UUID)
}
```

All possible events in your app should be listed in these enums and grouped the way you consider more relevant. When grouping these enums one thing to consider is modularity: you can split some or all these enums in different frameworks if you want strict boundaries between your modules and/or reuse the same group of actions among different apps.

For example, all apps will have common actions that represent life-cycle of any iOS app, such as `willResignActive`, `didBecomeActive`, `didEnterBackground`, `willEnterForeground`. If multiples apps need to know this life-cycle, maybe it's convenient to create an enum for this specific domain. The same for network reachability, we should consider creating an enum to represent all possible events we get from the system when our connection state changes, and this can be used in a wide variety of apps.

> **_IMPORTANT:_** Because enums in Swift don't have KeyPath as structs do, we strongly recommend reading [Action Enum Properties](docs/markdown/ActionEnumProperties.md) document and implementing properties for each case, either manually or using code generators, so later you avoid writing lots and lots of error-prone switch/case. We also offer some templates to help you on that.

---

### State

There's no "State" protocol or type in SwiftRex. However, State will be found as a generic parameter for most core data structures, meaning that it's up to you to define what is the root State type.

Conceptually, we can say that state represents the whole knowledge that an app holds while is open, usually in memory and mutable; it's like a paper on where you write down some values, and for every action you receive you erase one value and replace it by a different value. Another way of thinking about state is in a functional programming way: the state is not persisted, but it's the result of a function that takes the initial condition of your app plus all the actions it received since it was launched, and calculates the current values by applying chronologically all the action changes on top of the initial state. This is known as [Event Sourcing Design Pattern](https://martinfowler.com/eaaDev/EventSourcing.html) and it's becoming popular recently in some web backend services, such as [Kafka Event Sourcing](https://kafka.apache.org/uses).

In a device with limited battery and memory we can't afford having a true event-sourcing pattern because it would be too expensive recreating the whole history of an app every time someone requests a simple boolean. So we "cache" the new state every time an action is received, and this in-memory cache is precisely what we call "State" in SwiftRex. So maybe we mix both ways of thinking about State and come up with a better generalisation for what a state is.

> **STATE** is the result of a function that takes two arguments: the previous (or initial) state and some action that occurred, to determine the new state. This happens incrementally as more and more actions arrive. State is useful for **output** data to the user.

However, be careful, some things may look like state but they are not. Let's assume you have an app that shows an item price to the user. This price will be shown as `"$3.00"` in US, or `"$3,00"` in Germany, or maybe this product can be listed in british pounds, so in US we should show `"£3.00"` while in Germany it would be `"£3,00"`. In this example we have:
- Currency type (`£` or `$`)
- Numeric value (`3`)
- Locale (`en_US` or `de_DE`)
- Formatted string (`"$3.00"`, `"$3,00"`, `"£3.00"` or `"£3,00"`)

The formatted string itself is **NOT** state, because it can be calculated from the other properties. This can be called "derived state" and holding that is asking for inconsistency. We would have to remember to update this value every time one of the others change. So it's better off to represent this String either as a calculated property or a function of the other 3 values. The best place for this sort of derived state is in presenters or controllers, unless you have a high cost to recalculate it and in this case you could store in the state and be very careful about it. Luckily SwiftRex helps to keep the state consistent as we're about to see in the Reducer section, still, it's better off not duplicating information that can be easily and cheaply calculated.

For representing the state of an app we recommend value types: structs or enums. Tuples would be acceptable as well, but unfortunately Swift currently doesn't allow us to conform tuples to protocols, and we usually want our whole state to be Equatable and sometimes Codable.

```swift
struct AppState: Equatable {
    var appLifecycle: AppLifecycle
    var movies: Loadable<[Movie]> = .neverLoaded
    var currentFilter: MovieFilter
    var selectedMovie: UUID?
}

struct MovieFilter: Equatable {
    var stringFilter: String?
    var yearMin: Int?
    var yearMax: Int?
    var ratingMin: Int?
    var ratingMax: Int?
}

enum AppLifecycle: Equatable {
    case backgroundActive
    case backgroundInactive
    case foregroundActive
    case foregroundInactive
}

enum Loadable<T> {
    case neverLoaded
    case loading
    case loaded(T)
}
extension Loadable: Equatable where T: Equatable {}
```

Some properties represent a state-machine, for example the `Loadable` enum will eventually change from `.neverLoaded` to `.loading` and then to `.loaded([Movie])` in our `movies` property. Learning when and how to represent properties in this shape is a matter of experimenting more and more with SwiftRex and getting used to this architecture. Eventually this will become natural and you can start writing your own data structures to represent such state-machines, that will be very useful in countless situations.

Annotating the whole state as Equatable helps us to reduce the UI updates in case view models are not used, but this is not a strong requirement and there are other ways to also avoid that, although we still recommend it. Annotating the state as Codable can be useful for logging, debugging, crash reports, monitors, etc and this is also recommended if possible.

---

## Core Parts
- [Store](#store)
- [Middleware](#middleware)
    - [EffectMiddleware](#effectmiddleware)
- [Reducer](#reducer)

---

### Store

`Store` is a class that you want to create and keep alive during the whole execution of an app, because its only responsibility is to act as a coordinator for the Unidirectional Dataflow lifecycle. That's also why we want one and only one instance of a Store, so either you create a static instance singleton, or keep it in your AppDelegate. Be careful with SceneDelegate if your app supports multiple windows and you want to share the state between these multiple instances of your app, which you usually want. That's why AppDelegate, singleton or global variable is usually recommended for the Store, not SceneDelegate.

SwiftRex will provide a protocol and a base type for helping you to create your own Store. Let's learn about them.

#### StoreType
`StoreType` is the protocol that defines the minimum implementation requirement of a Store, and it's actually composed only by two other protocols, one for the store input and one for the store output.

##### 1. ActionHandler
`ActionHandler`: that's the store input, so it makes it able to receive and distribute events of generic type `ActionType`. Being an action handler means that an `UIViewController` or SwiftUI View can dispatch events to it, such as `.userTappedButtonX`, `.didScrollToPosition(_:)`, `.viewDidLoad` or `queryTextFieldChangedTo(_:)`. There's only one requirement:

```swift
func dispatch(_ action: ActionType, from dispatcher: ActionSource)
```

It gives for free another dispatch function:
```swift
func dispatch(_ action: ActionType, file: String = #file, function: String = #function, line: UInt = #line, info: String? = nil)
```

Most of the times, users will only provide the first parameter, `action: ActionType`, and the rest will be collected automatically from where the action was dispatched from. This is useful for log and analytics purposes, we can track the source of each action.

```swift
// Usage:
store.dispatch(.appStarted) // this collects automatically the dispatcher
```

Because `ActionType` is generic, when you dispatch you don't have to provide the full enum name, only the case. This also avoids mistakes as it's compiled-checked.

##### 2. StateProvider
`StateProvider`: that's the store output, so the system can subscribe a store for updates on State. Being a state provider basically means that store is an `Observable` (`RxSwift`) or a `Publisher` (`Combine`) of state elements, and an `UIViewController` or SwiftUI View can subscribe to the store and react to state changes. There's only one requirement:

```swift
var statePublisher: UnfailablePublisherType<StateType> { get }
```

The `UnfailablePublisherType<StateType>` is an abstraction that will be implemented as `Observable`, `Publisher` or `SignalProducer` according to the selected Reactive Framework, and emits the element `StateType` (your root app state) with `Never` type for failure, when the framework supports it.

```swift
// Combine Usage:
let cancellable = store.statePublisher.sink { value in
    print("Got new state: \(value)") 
}
// RxSwift Usage:
let disposable = store.statePublisher.subscribe(onNext: { value in
    print("Got new state: \(value)") 
})
```

There are other ways to observe a Store, such as SwiftUI ObservableObject protocol, but these tools are built on top of this very simple `StateProvider` protocol.

#### StoreType Flow

Either using UIKit, AppKit, WatchKit, SwiftUI or any other presentation layer, the communication between a Store and the UI will happen exclusively through these two members, `dispatch` for input actions and `statePublisher` for output state.

[![ViewController and Store](https://swiftrex.github.io/SwiftRex/markdown/img/Redux1.gif)](https://www.youtube.com/watch?v=oBR94I2p2BA)

As seen in the animation above, the Store only exposes an input (action) and an output (state provider), and that's all the Views need to know about the Store.

> **_IMPORTANT:_** However you should only have one store, you can have multiple projections of this store and give to your views, for example, that way they will only have a limited amount of operations and state available and can't mess with things that are out of their responsibilities. This is also the perfect way to modularize an app, as multiples projections can live in different frameworks and later only assembled together in the main target. We will talk more about that on chapter [Store Projection](#store-projection), but for now it's only important to understand that Store Projections won't hold source-of-truth, but will pretend to be a real store, therefore, implement the `StoreType` protocol, and the flow above will still be valid regardless of being the real singleton Store or a simple projection of it.

#### ReduxStoreBase
`ReduxStoreBase` is an `open class` that conforms to `StoreType` and provides all we need to start using SwiftRex. You can choose to inherit from this class or use it directly. We recommend inheritance because this will allow you to better mock the Store if necessary, however there's nothing you really have to write once `ReduxStoreBase` is complete: it glues all the parts together and acts as a proxy to the non-Redux world.

A suggested `Store` can be written with no more than 10 lines of code:
```swift
class Store: ReduxStoreBase<AppAction, AppState> {
    init(world: World) {
        super.init(
            subject: .combine(initialValue: AppState()),
            reducer: appReducer,
            middleware: appMiddleware().inject(world),
            emitsValue: .whenDifferent
        )
    }
}
```

The `ReduxStoreBase` initialiser expects a middleware and a reducer as input, and that's enough for the store to coordinate the entire process. It creates a queue of incoming actions that will be handled by the middleware pipeline and by the reducer pipeline. By the end of this process the state may or may not change, as a result of reducer pipeline acting on action + current state. Finally, the store notifies all subscribers about the state change and only then starts evaluating the next action on the queue.

![Store internals](https://swiftrex.github.io/SwiftRex/markdown/img/StoreInternals.png)

We will see more in depth this dataflow when reading about middlewares and reducers, but please come back to this picture above every time you read about the store internals, it can be very useful.

At this point all you have to notice is the action handler (dispatch action function) and the state provider (subscribe state) boxes that are shown to the outside world. When writing UIViewControllers or SwiftUI Views those are the only 2 functions you'll ever have to use.

There will be only one honest Store in your entire app, so either you create it as a singleton or a property in a long-living class such as AppDelegate or AppCoordinator. That's crucial for making the store completely detached from the `UIKit`/SwiftUI world.

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

### Middleware

`Middleware` is a plugin, or a composition of several plugins, that are assigned to the `ReduxStoreProtocol` pipeline in order to handle each action received (`InputActionType`), to execute side-effects in response, and eventually dispatch more actions (`OutputActionType`) in the process.
This happens before the `Reducer` to do its job.

We can think of a Middleware as an object that transforms actions into sync or async tasks and create more actions as these side-effects complete, also being able to check the current state at any point.

An action is a lightweight structure, typically an enum, that is dispatched into the `ActionHandler` (usually a `StoreProtocol`).
A Store like `ReduxStoreProtocol` enqueues a new action that arrives and submits it to a pipeline of middlewares. So, in other words, a `Middleware` is class that handles actions, and has the power to dispatch more actions to the `ActionHandler` chain. The `Middleware` can also simply ignore the action, or it can execute side-effects in response, such as logging into file or over the network, or execute http requests, for example. In case of those async tasks, when they complete the middleware can dispatch new actions containing a payload with the response (a JSON file, an array of movies, credentials, etc). Other middlewares will handle that, or maybe even the same middleware in a future RunLoop, or perhaps some `Reducer`, as reducers pipeline is at the end of every middleware pipeline.

Middlewares can schedule a callback to be executed after the reducer pipeline is done mutating the global state. At that point, the middleware will have access to the new state, and in case it cached the old state it can compare them, log, audit, perform analytics tracking, telemetry or state sync with external devices, such as Apple Watches. Remote Debugging over the network is also a great use of a Middleware.

Every action dispatched also comes with its action source, which is the primary dispatcher of that action. Middlewares can access the file, line, function and additional information about the entity responsible for creating and dispatching that action, which is a very powerful debugging information that can help developers to trace how the information flows through the app.

Because the `Middleware` receive all actions and accesses the state of the app at any point, anything can be done from these small and reusable boxes. For example, the same `CoreLocation` middleware could be used from an iOS app, its extensions, the Apple Watch extension or even different apps, as long as they share some sub-state struct.

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
                   ┌─────┐                                                                                        ┌─────┐
                   │     │     handle   ┌──────────┐ request      ┌ ─ ─ ─ ─  response     ┌──────────┐ dispatch   │     │
                   │     │   ┌─────────▶│Middleware├─────────────▶ External│─────────────▶│Middleware│───────────▶│Store│─ ─ ▶ ...
                   │     │   │ Action   │ Pipeline │ side-effects │ World    side-effects │ callback │ New Action │     │
                   │     │   │          └──────────┘               ─ ─ ─ ─ ┘              └──────────┘            └─────┘
 ┌──────┐ dispatch │     │   │                ▲
 │Button│─────────▶│Store│──▶│                └───afterReducer─────┐                   ┌────────┐
 └──────┘ Action   │     │   │                                     │                ┌─▶│ View 1 │
                   │     │   │                                  ┌─────┐             │  └────────┘
                   │     │   │ reduce   ┌──────────┐            │     │ onNext      │  ┌────────┐
                   │     │   └─────────▶│ Reducer  ├───────────▶│Store│────────────▶├─▶│ View 2 │
                   │     │     Action   │ Pipeline │ New state  │     │ New state   │  └────────┘
                   └─────┘     +        └──────────┘            └─────┘             │  ┌────────┐
                               State                                                └─▶│ View 3 │
                                                                                       └────────┘
```

Middleware protocol is generic over 3 associated types:

#### InputActionType:
The Action type that this `Middleware` knows how to handle, so the store will forward actions of this type to this middleware.
Thanks to optics, this action can be a sub-action lifted to a global action type in order to compose with other middlewares acting on the global action of an app. Please check `lift(inputAction:outputAction:state:)` for more details.

#### OutputActionType:
The Action type that this `Middleware` will eventually trigger back to the store in response of side-effects. This can be the same as `InputActionType` or different, in case you want to separate your enum in requests and responses.
Thanks to optics, this action can be a sub-action lifted to a global action type in order to compose with other middlewares acting on the global action of an app. Please check `lift(inputAction:outputAction:state:)` for more details.

#### StateType:
The State part that this `Middleware` needs to read in order to make decisions. This middleware will be able to read the most up-to-date `StateType` from the store at any point in time, but it can never write or make changes to it. In some cases, middleware don't need reading the whole global state, so we can decide to allow only a sub-state, or maybe this middleware doesn't need to read any state, so the `StateType`can safely be set to `Void`.
Thanks to lenses, this state can be a sub-state lifted to a global state in order to compose with other middlewares acting on the global state of an app. Please check `lift(inputAction:outputAction:state:)` for more details.

When implementing your Middleware, all you have to do is to handle the incoming actions:

```swift
class LoggerMiddleware: Middleware {
    typealias InputActionType = AppGlobalAction // It wants to receive all possible app actions
    typealias OutputActionType = Never          // No action is generated from this Middleware
    typealias StateType = AppGlobalState        // It wants to read the whole app state

    var getState: GetState<AppGlobalState>!

    func receiveContext(getState: @escaping GetState<AppGlobalState>, output: AnyActionHandler<Never>) {
        self.getState = getState
    }

    func handle(action: AppGlobalAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        let stateBefore: AppGlobalState = getState()
        let dateBefore = Date()

        afterReducer = .do {
            let stateAfter = self.getState()
            let dateAfter = Date()
            let source = "\(dispatcher.file):\(dispatcher.line) - \(dispatcher.function) | \(dispatcher.info ?? "")"

            Logger.log(action: action, from: source, before: stateBefore, after: stateAfter, dateBefore: dateBefore, dateAfter: dateAfter)
        }
    }
}

class FavoritesAPIMiddleware: Middleware {
    typealias InputActionType = FavoritesAction  // It wants to receive only actions related to Favorites
    typealias OutputActionType = FavoritesAction // It wants to also dispatch actions related to Favorites
    typealias StateType = FavoritesModel         // It wants to read the app state that manages favorites

    var getState: GetState<FavoritesModel>!
    var output: AnyActionHandler<FavoritesAction>!

    func receiveContext(getState: @escaping GetState<FavoritesModel>, output: AnyActionHandler<FavoritesAction>) {
        self.getState = getState
        self.output = output
    }

    func handle(action: FavoritesAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        guard let .toggleFavorite(movieId) = action else { return }

        let favoritesList = getState()
        let makeFavorite = !favoritesList.contains(where: { $0.id == movieId })

        API.changeFavorite(id: movieId, makeFavorite: makeFavorite) (completion: { result in
            switch result {
            case let .success(value):
                self.output.dispatch(.changedFavorite(movieId, isFavorite: true), info: "API.changeFavorite callback")
            case let .failure(error):
                self.output.dispatch(.changedFavoriteHasFailed(movieId, isFavorite: false, error: error), info: "API.changeFavorite callback")
            }
        })
    }
}
```

#### EffectMiddleware
This is a middleware implementation that aims for simplicity while keeping it very powerful. For every incoming action you must return an Effect, which is simply a wrapper for a reactive
Observable, Publisher or SignalProducer, depending on your favourite reactive library. The only condition is that the Output (Element) of your reactive stream must be a DispatchedAction and
the Error must be Never. DispatchedAction is a struct having the action itself and the dispatcher (action source), so it's generic over the Action and matches the OutputAction of the
EffectMiddleware. Error must be Never because Middlewares are expected to resolve all side-effects, including Errors. So if you want to treat the error, you can do it in the middleware, if
you want to warn the user about the error, then you catch the error in your reactive stream and transform it into an Action such as `.somethingWentWrong(messageToTheUser: String)` to be
dispatched and later reduced into the AppState.

Optionally an EffectMiddleware can also handle Dependencies. This helps to perform Dependency Injection into the middleware. If your Dependency generic parameter is Void, then the Middleware
can be created immediately without passing any dependency, however you can't use any external dependency when handling the action. If Dependency generic parameter has some type, or tuple,
then you can use them while handling the action, but in order to create the effect middleware you will need to provide that type or tuple.

Important: the dependency will be available inside the Effect closure only, because it's expected that you "access" the external world only while executing an Effect.

```swift
static let favouritesMiddleware = EffectMiddleware<FavoritesAction /* input action */, FavoritesAction /* output action */, AppState, FavouritesAPI /* dependencies */>.onAction { incomingAction, dispatcher, getState in
    switch incomingAction {
    case let .toggleFavorite(movieId):
        return Effect(token: "Any Hashable. Use this to cancel tasks, or to avoid two tasks of the same type") { context -> AnyPublisher<DispatchedAction<FavoritesAction>, Never> in
            let favoritesList = getState()
            let makeFavorite = !favoritesList.contains(where: { $0.id == movieId })
            let api = context.dependencies

            return api.changeFavoritePublisher(id: movieId, makeFavorite: makeFavorite)
                      .catch { error in DispatchedAction(.somethingWentWrong("Got an error: \(error)") }
                      .eraseToAnyPublisher()
        }
    default:
        return .doNothing // Special type of Effect that, well, does nothing.
    }
}
```

Effect has some useful constructors such as `.doNothing`, `.fireAndForget`, `.just`, `.sequence`, `.promise`, `.toCancel` and others. Also, you can lift any Publisher, Observable or SignalProducer into an Effect, as
long as it matches the required generic parameters, for that you can simply use `.asEffect()` functions.

![SwiftUI Side-Effects](https://swiftrex.github.io/SwiftRex/markdown/img/wwdc2019-226-02.jpg)

### Reducer

`Reducer` is a pure function wrapped in a monoid container, that takes current state and an action to calculate the new state.

The `Middleware` pipeline can do two things: dispatch outgoing actions and handling incoming actions. But what they can NOT do is changing the app state. Middlewares have read-only access to the up-to-date state of our apps, but when mutations are required we use the `Reducer` function.

```swift
// Signature:
Reducer.reduce(_ reduce: @escaping MutableReduceFunction<ActionType, StateType>)

// Example:
let someReducer = Reducer.reducer { action, state in
    switch action {
    case something:
        // given that state is "inout", you can mutate it here:
        state.somethingCalledCount += 1
    }
}
```

Given the current state (as a mutable inout) and an action, it can change the state. This function will be executed right after middleware action handling for all the middlewares in the
pipeline. Because a reduce function is composable monoid and also can be lifted through lenses, it's possible to write fine-grained "sub-reducer" that will handle only a "sub-state", creating a pipeline of reducers. For example, you can write a Reducer to handle part A of certain state, another Reducer to handle part B of certain state, "lift" them both to the common
state that holds A and B (a parent struct, for example, that has properties A and B), and then combine them into one.

It's important to understand that reducer is a synchronous operations that calculates a new state without any kind of side-effect, so never add properties to the `Reducer` structs or call any external function. If you are tempted to do that, please create a middleware. Reducers are also responsible for keeping the consistency of a state, so it's always good to do a final sanity check before changing the state.

Once the reducer function executes, the store will update its single source of truth with the new calculated state, and propagate it to all its observers.

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

## Projection and Lifting
- [Store Projection](#store-projection)
- [Lifting Middleware](#lifting-middleware)
- [Lifting Reducer](#lifting-reducer)

### Store Projection

TBD

![Store Projection](https://swiftrex.github.io/SwiftRex/markdown/img/StoreProjectionDiagram.png)

### Lifting Middleware

TBD

### Lifting Reducer

TBD

# Architecture

This dataflow is, somehow, an implementation of MVC, one that differs significantly from the Apple's MVC for offering a very strict and opinative description of layers' responsibilities and by enforcing the growth of the Model layer, through a better definition of how it should be implemented: in this scenario, the Model is the Store. All your Controller has to do is to forward view actions to the Store and subscribe to state changes, updating the views whenever needed. If this flow doesn't sound like MVC, let's check a picture taken from Apple's website:

![iOS MVC](https://swiftrex.github.io/SwiftRex/markdown/img/CocoaMVC.gif)

One important distinction is about the user action: on SwiftRex it's forwarded by the controller and reaches the Store, so the responsibility of updating the state becomes the Store's responsibility now. The rest is pretty much the same, but with a better definition of how the Model operates.

```
     ╼━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╾
    ╱░░░░░░░░░░░░░░░░░◉░░░░░░░░░░░░░░░░░░╲
  ╱░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░╲
 ┃░░░░░░░░░░░░░◉░░◖■■■■■■■◗░░░░░░░░░░░░░░░░░┃
 ┃░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░┃
╭┃░╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮░┃
│┃░┃             ┌──────────┐             ┃░┃
╰┃░┃             │ UIButton │────────┐    ┃░┃
 ┃░┃             └──────────┘        │    ┃░┃
╭┃░┃         ┌───────────────────┐   │    ┃░┃╮ dispatch<Action>(_ action: Action)
│┃░┃         │UIGestureRecognizer│───┼──────────────────────────────────────────────┐
│┃░┃         └───────────────────┘   │    ┃░┃│                                      │
╰┃░┃             ┌───────────┐       │    ┃░┃│                                      ▼
╭┃░┃             │viewDidLoad│───────┘    ┃░┃╯                           ┏━━━━━━━━━━━━━━━━━━━━┓
│┃░┃             └───────────┘            ┃░┃                            ┃                    ┃░
│┃░┃                                      ┃░┃                            ┃                    ┃░
╰┃░┃                                      ┃░┃                            ┃                    ┃░
 ┃░┃               ┌───────┐              ┃░┃                            ┃                    ┃░
 ┃░┃               │UILabel│◀─ ─ ─ ─ ┐    ┃░┃                            ┃                    ┃░
 ┃░┃               └───────┘              ┃░┃  Combine, RxSwift    ┌ ─ ─ ┻ ─ ┐                ┃░
 ┃░┃                                 │    ┃░┃  or ReactiveSwift       State      Store        ┃░
 ┃░┃        ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ╋░─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─│Publisher│                ┃░
 ┃░┃        ▼               │             ┃░┃  subscribe(onNext:)                             ┃░
 ┃░┃ ┌─────────────┐        ▼             ┃░┃  sink(receiveValue:) └ ─ ─ ┳ ─ ┘                ┃░
 ┃░┃ │  Diffable   │ ┌─────────────┐      ┃░┃  assign(to:on:)            ┃                    ┃░
 ┃░┃ │ DataSource  │ │RxDataSources│      ┃░┃                            ┃                    ┃░
 ┃░┃ └─────────────┘ └─────────────┘      ┃░┃                            ┃                    ┃░
 ┃░┃        │               │             ┃░┃                            ┃                    ┃░
 ┃░┃ ┌──────▼───────────────▼───────────┐ ┃░┃                            ┗━━━━━━━━━━━━━━━━━━━━┛░
 ┃░┃ │                                  │ ┃░┃                             ░░░░░░░░░░░░░░░░░░░░░░
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ │         UICollectionView         │ ┃░┃
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ └──────────────────────────────────┘ ┃░┃
 ┃░╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯░┃
 ┃░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░┃
 ┃░░░░░░░░░░░░░░░░░░░▓▓▓▓░░░░░░░░░░░░░░░░░░░┃
 ┃░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░┃
  ╲░░░░░░░░░░░░░░░░░░▓▓▓▓░░░░░░░░░░░░░░░░░░╱
    ╲░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░╱
     ╼━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╾
```

You can think of Store as a very heavy "Model" layer, completely detached from the View and Controller, and where all the business logic stands. At a first sight it may look like transferring the "Massive" problem from a layer to another, so that's why the Store is nothing but a collection of composable boxes with very well defined roles and, most importantly, restrictions.

```
     ╼━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╾
    ╱░░░░░░░░░░░░░░░░░◉░░░░░░░░░░░░░░░░░░╲
  ╱░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░╲
 ┃░░░░░░░░░░░░░◉░░◖■■■■■■■◗░░░░░░░░░░░░░░░░░┃
 ┃░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░┃
╭┃░╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮░┃
│┃░┃               ┌────────┐             ┃░┃
╰┃░┃               │ Button │────────┐    ┃░┃
 ┃░┃               └────────┘        │    ┃░┃              ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐             ┏━━━━━━━━━━━━━━━━━━━━━━━┓
╭┃░┃          ┌──────────────────┐   │    ┃░┃╮ dispatch                                            ┃                       ┃░
│┃░┃          │      Toggle      │───┼────────────────────▶│   ─ ─ ─ ─ ─ ─ ─ ─ ─ ─▶  │────────────▶┃                       ┃░
│┃░┃          └──────────────────┘   │    ┃░┃│ view event      f: (Event) → Action     app action  ┃                       ┃░
╰┃░┃              ┌──────────┐       │    ┃░┃│             │                         │             ┃                       ┃░
╭┃░┃              │ onAppear │───────┘    ┃░┃╯                                                     ┃                       ┃░
│┃░┃              └──────────┘            ┃░┃              │   ObservableViewModel   │             ┃                       ┃░
│┃░┃                                      ┃░┃                                                      ┃                       ┃░
╰┃░┃                                      ┃░┃              │     a projection of     │  projection ┃         Store         ┃░
 ┃░┃                                      ┃░┃                   the actual store                   ┃                       ┃░
 ┃░┃                                      ┃░┃              │                         │             ┃                       ┃░
 ┃░┃      ┌────────────────────────┐      ┃░┃                                                      ┃                       ┃░
 ┃░┃      │                        │      ┃░┃              │                         │            ┌┃─ ─ ─ ─ ─ ┐            ┃░
 ┃░┃      │    @ObservedObject     │◀ ─ ─ ╋░─ ─ ─ ─ ─ ─ ─ ─    ◀─ ─ ─ ─ ─ ─ ─ ─ ─ ─   ◀─ ─ ─ ─ ─ ─    State                ┃░
 ┃░┃      │                        │      ┃░┃  view state  │   f: (State) → View     │  app state │ Publisher │            ┃░
 ┃░┃      └────────────────────────┘      ┃░┃                               State                  ┳ ─ ─ ─ ─ ─             ┃░
 ┃░┃        │          │          │       ┃░┃              └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘             ┗━━━━━━━━━━━━━━━━━━━━━━━┛░
 ┃░┃        ▼          ▼          ▼       ┃░┃                                                       ░░░░░░░░░░░░░░░░░░░░░░░░░
 ┃░┃   ┌────────┐ ┌────────┐ ┌────────┐   ┃░┃
 ┃░┃   │  Text  │ │  List  │ │ForEach │   ┃░┃
 ┃░┃   └────────┘ └────────┘ └────────┘   ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯░┃
 ┃░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░┃
 ┃░░░░░░░░░░░░░░░░░░░▓▓▓▓░░░░░░░░░░░░░░░░░░░┃
 ┃░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░┃
  ╲░░░░░░░░░░░░░░░░░░▓▓▓▓░░░░░░░░░░░░░░░░░░╱
    ╲░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░╱
     ╼━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╾
```

And what about SwiftUI? Is this architecture a good fit for the new UI framework? In fact, this architecture works even better in SwiftUI, because SwiftUI was inspired by several functional patterns and it's reactive and stateless by conception. It was said multiple times during WWDC 2019 that, in SwiftUI, the **View is a function of the state**, and that we should always aim for single source of truth and the data should always flow in a single direction.

![SwiftUI Unidirectional Flow](https://swiftrex.github.io/SwiftRex/markdown/img/wwdc2019-226-01.jpg)

# Installation

## CocoaPods

Create or modify the Podfile at the root folder of your project. Your settings will depend on the ReactiveFramework of your choice.

For Combine:
```ruby
# Podfile
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

target 'MyAppTarget' do
  pod 'CombineRex'
end
```

For RxSwift:
```ruby
# Podfile
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

target 'MyAppTarget' do
  pod 'RxSwiftRex'
end
```

For ReactiveSwift:
```ruby
# Podfile
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

target 'MyAppTarget' do
  pod 'ReactiveSwiftRex'
end
```

As seen above, some lines are optional because the final Podspecs already include the correct dependencies.

Then, all you must do is install your pods and open the `.xcworkspace` instead of the `.xcodeproj` file:

```shell
$ pod install
$ xed .
```

## Swift Package Manager

Create or modify the Package.swift at the root folder of your project.
You can use the automatic linking mode (static/dynamic), or use the project with suffix Dynamic to force
dynamic linking and overcome current Xcode limitations to resolve diamond dependency issues.

If you use it from only one target, automatic mode should be fine.

Combine, automatic linking mode:
```swift
// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "MyApp",
  platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
  products: [
    .executable(name: "MyApp", targets: ["MyApp"])
  ],
  dependencies: [
    .package(url: "https://github.com/SwiftRex/SwiftRex.git", from: "0.8.2")
  ],
  targets: [
    .target(name: "MyApp", dependencies: [.product(name: "CombineRex", package: "SwiftRex")])
  ]
)
```

RxSwift, automatic linking mode:
```swift
// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "MyApp",
  platforms: [.macOS(.v10_10), .iOS(.v8), .tvOS(.v9), .watchOS(.v3)],
  products: [
    .executable(name: "MyApp", targets: ["MyApp"])
  ],
  dependencies: [
    .package(url: "https://github.com/SwiftRex/SwiftRex.git", from: "0.8.2")
  ],
  targets: [
    .target(name: "MyApp", dependencies: [.product(name: "RxSwiftRex", package: "SwiftRex")])
  ]
)
```

ReactiveSwift, automatic linking mode:
```swift
// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "MyApp",
  platforms: [.macOS(.v10_10), .iOS(.v8), .tvOS(.v9), .watchOS(.v3)],
  products: [
    .executable(name: "MyApp", targets: ["MyApp"])
  ],
  dependencies: [
    .package(url: "https://github.com/SwiftRex/SwiftRex.git", from: "0.8.2")
  ],
  targets: [
    .target(name: "MyApp", dependencies: [.product(name: "ReactiveSwiftRex", package: "SwiftRex")])
  ]
)
```

Combine, dynamic linking mode (use similar approach of appending "Dynamic" also for RxSwift or ReactiveSwift products):
```swift
// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "MyApp",
  platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
  products: [
    .executable(name: "MyApp", targets: ["MyApp"])
  ],
  dependencies: [
    .package(url: "https://github.com/SwiftRex/SwiftRex.git", from: "0.8.2")
  ],
  targets: [
    .target(name: "MyApp", dependencies: [.product(name: "CombineRexDynamic", package: "SwiftRex")])
  ]
)
```

Then you can either building on the terminal or use Xcode 11 or higher that now supports SPM natively.

```shell
$ swift build
$ xed .
```

## Carthage

Carthage is no longer supported due to lack of interest and high maintenance effort.

In case this is REALLY critical for you, please open a Github issue and let us know, we will evaluate
the possibility to bring it back. In meantime you can check last  Carthage compatible version, which
was 0.7.1, and eventually target that version until we come up with a better solution.
