<p align="center">
	<a href="https://github.com/SwiftRex/SwiftRex/"><img src="https://swiftrex.github.io/SwiftRex/markdown/img/SwiftRexBanner.png" alt="SwiftRex" /></a><br /><br />
	Unidirectional Dataflow for Swift<br /><br />
</p>

![Build Status](https://github.com/SwiftRex/SwiftRex/actions/workflows/ci.yml/badge.svg?branch=main)
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-orange.svg)](https://swiftpackageindex.com/SwiftRex/SwiftRex)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FSwiftRex%2FSwiftRex%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/SwiftRex/SwiftRex)
[![Platform support](https://img.shields.io/badge/platform-iOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20macOS%20%7C%20visionOS%20%7C%20Linux-252532.svg)](https://github.com/SwiftRex/SwiftRex)
[![License Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/SwiftRex/SwiftRex/blob/main/LICENSE)

# Introduction

SwiftRex is a framework that combines Unidirectional Dataflow architecture and reactive programming (Swift Concurrency (async/await), [Combine](https://developer.apple.com/documentation/combine), [RxSwift](https://github.com/ReactiveX/RxSwift) or [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift)), providing a central state Store for the whole state of your app, of which your SwiftUI Views or UIViewControllers can observe and react to, as well as dispatching events coming from the user interactions.

This pattern, also known as ["Redux"](https://redux.js.org/basics/data-flow), allows us to rethink our app as a single [pure function](https://en.wikipedia.org/wiki/Pure_function) that receives user events as input and returns UI changes in response. The benefits of this workflow will hopefully become clear soon.

[API documentation can be found here](https://swiftrex.github.io/SwiftRex/documentation/swiftrex).

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
    <p>Reactive frameworks and Swift Concurrency help to make this more uniform and composable, and frameworks like Combine and SwiftUI have made it easier than ever to express async pipelines in a consistent way.</p>
    <p>But composing lots of services in reactive pipelines is not always easy and has its own pitfalls, like full pipeline cancellation because one stream emitted an error, event reentrancy and, last but not least, steep learning curve on mastering the several operators.</p>
    <p>SwiftRex uses reactive-programming and async/await a lot, and allows you to use them as much as you feel comfortable. However we also offer a more uniform way to compose different services with only 1 data type and 2 operators: middleware, `<>` operator and `lift` operator, all the other operations can be simplified by triggering actions to itself, other middlewares or state reducers. You still have the option to create a larger middleware and handle multiple sources in a traditional reactive-stream fashion, if you like, but this can be overwhelming for un-experienced developers, harder to test and harder to reuse in different apps.</p>
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
    <p>UIViewControllers have a very peculiar ownership model: you don't control it. The view controllers are kept in memory while they are in the navigation stack, or if a tab is presented, or while a modal view is shown, but they can be released at any point, and with it, anything you put the ownership under view controller umbrella. All those [weak self] we've been using and loving can actually be weak sometimes, and it's very easy to not reason about that when we "guard that else return". Any important task that MUST be completed, regardless of your view being shown or not, should not be under the view controller life-cycle, as the user can easily dismiss your modal or pop your view. SwiftUI has improved that but it's still possible to start async tasks from views' closures, and although now that view is a value-type it's a bit harder to make those mistakes, it's still possible.</p>
    <p>SwiftRex solves this problem by enforcing that all and every side-effect or async task should be done by the middleware, not the views. And middleware life-cycle is owned by the store, so we shouldn't expect any unfortunate surprise as long as the store lives while the app lives.</p>
    <p>You still can dispatch "viewDidLoad", "onAppear", "onDisappear" events from your views, in order to perform task cancellations, so you gain more control, not less.</p>
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
  <p><code>SwiftRex.Testing</code> ships a <code>TestStore</code> built directly into SwiftRex — no separate package needed. It gives you a deterministic, exhaustive test harness with mandatory state assertions on every dispatch and Prism-based action validation for <code>receive</code>. See the <a href="#testing">Testing</a> section below for full examples. <a href="https://github.com/SwiftRex/InstrumentationMiddleware">InstrumentationMiddleware</a> allows you to use Instruments to see what's happening in a SwiftRex app, and <a href="https://github.com/SwiftRex/LoggerMiddleware">LoggerMiddleware</a> is a very powerful logger to be used by developers to easily understand what's happening in runtime.</p>
</details>

I'm not gonna lie, it's a completely different way of writing apps, as most reactive approaches are; but once you get used to, it makes more sense and enables you to reuse much more code between your projects, gives you better tooling for writing software, testing, debugging, logging and finally thinking about events, state and mutation as you've never done before. And I promise you, it's gonna be a way with no return, a unidirectional journey.

# Integration Options

SwiftRex supports multiple concurrency styles. The core package is self-contained and sufficient on its own; the reactive, concurrency, and testing bridges are optional add-ons:

| Product | Trait | When to use |
|---|---|---|
| `SwiftRex` | — | Always — the core store, reducers, behaviors, effects |
| `SwiftRex.SwiftConcurrency` | — | async/await — Effect bridges for `Task`, `AsyncSequence`; `store.stream` |
| `SwiftRex.Combine` | — | Apple Combine integration — `asEffect()` on `Publisher`, `store.publisher`, `ctx.readLiveState() -> AnyPublisher` |
| `SwiftRex.RxSwift` | `RxSwift` | RxSwift integration — `asEffect()` on `Observable`, `store.observable`, `ctx.readLiveState() -> Observable` |
| `SwiftRex.ReactiveSwift` | `ReactiveSwift` | ReactiveSwift integration — `asEffect()` on `SignalProducer`/`Signal`, `store.signal`, `ctx.readLiveState() -> SignalProducer` |
| `SwiftRex.ReactiveConcurrency` | `ReactiveConcurrency` | [ReactiveConcurrency](https://github.com/luizmb/ReactiveConcurrency) integration — `asEffect()` on its async/await-native `Publisher`, `store.publisher`, `ctx.readLiveState() -> Publisher` |
| `SwiftRex.SwiftUI` | — | SwiftUI helpers — `ViewStore`/`TrackedViewStore` (`@Observable`, iOS 17+), `ObservableObjectStore`/`asObservableObject()` (Combine, iOS 13+), store-backed `Binding`s |
| `SwiftRex.Architecture` | — | Opinionated feature pattern — the `@Feature(type:strategy:)` macro, `@BoundTo`, `@Tracked` (Swift 6.3+) |
| `SwiftRex.Testing` | — | Test target only — `TestStore` for deterministic unit tests |

Pick the module(s) that match your project's reactive strategy. For a pure Swift Concurrency setup with no third-party dependencies, `SwiftRex` + `SwiftRex.SwiftConcurrency` is sufficient.

> **Opt-in bridges via package traits.** The three third-party reactive bridges — `SwiftRex.RxSwift`, `SwiftRex.ReactiveSwift`, and `SwiftRex.ReactiveConcurrency` — are each gated behind a [Swift Package Manager **trait**](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md) of the same name. **All traits are off by default**, so a consumer who picks one bridge never downloads — nor sees in their acknowledgements — the other two third-party packages. `SwiftRex.Combine` (system framework) and `SwiftRex.SwiftConcurrency` (no third-party dependency) need no trait. Requires a Swift 6.3+ toolchain. See [Installation](#installation) for how to enable a trait.

## Swift Concurrency

`SwiftRex.SwiftConcurrency` bridges the Effect system to Swift's async/await world:

- `Effect.task { await myAsyncFunc() }` — wraps a single async computation
- `Effect.throwingTask(MyAction.result) { try await api.fetch() }` — throwing async work with automatic `Result` mapping
- `Effect.asyncSequence(myAsyncStream, MyAction.received)` — bridges any `AsyncSequence` into a stream of dispatched actions
- `store.stream` — a `@Sendable () -> AsyncStream<State>` factory; each call starts a fresh observation: `for await state in store.stream() { ... }`

```swift
let fetchMiddleware = Middleware<AppAction, AppState, API>.handle { action, _ in
    guard case .fetchData = action else { return .doNothing }
    return Reader { ctx in
        Effect.throwingTask(AppAction.fetchResult) {
            try await ctx.environment.loadData()
        }
    }
}
```

`SwiftRex.SwiftConcurrency` uses Swift's native, *eager* `Task`/`AsyncStream` directly. If you want the lazy, referentially-transparent equivalents (`DeferredTask`, `DeferredStream`) plus a cold, composable `Publisher`, reach for `SwiftRex.ReactiveConcurrency` instead.

## ReactiveConcurrency

`SwiftRex.ReactiveConcurrency` bridges the Effect system to [ReactiveConcurrency](https://github.com/luizmb/ReactiveConcurrency)'s cold, async/await-native `Publisher` — a `Sendable`, Combine-shaped stream backed by `DeferredStream`:

- `publisher.asEffect()` / `.asEffect(AppAction.didReceive)` — map each element to an action (the call-site is captured as the `ActionSource`)
- `publisher.asEffect(AppAction.didFetch)` on a failing `Publisher<_, Failure>` — delivers `Result<Output, Failure>`
- `Effect.fireAndForget(publisher)` — run a pipeline for its side effects only
- `store.publisher` — a cold `Publisher<State, Never>` emitting state after every mutation
- `ctx.readLiveState()` — a single-element `Publisher<State, Never>` for reading post-mutation state inside a `produce` closure

```swift
let searchMiddleware = Middleware<AppAction, AppState, API>.handle { action, _ in
    guard case .search(let query) = action else { return .doNothing }
    return Reader { ctx in
        ctx.environment.search(query)        // a ReactiveConcurrency Publisher<[Result], APIError>
            .asEffect(AppAction.didSearch)   // Publisher → Effect, errors flow as Result
    }
}
```

> Enable the `ReactiveConcurrency` trait to use this product — see [Installation](#installation).

# Parts

Let's understand the components of SwiftRex by splitting them into 3 sections:
- [Conceptual parts](#conceptual-parts)
    - [Action](#action)
    - [State](#state)
- [Core Parts](#core-parts)
    - [Store](#store)
        - [StoreType](#storetype)
        - [Real Store](#real-store)
        - [Store Projection](#store-projection)
        - [Store Buffer](#store-buffer)
        - [All together](#all-together)
    - [Middleware](#middleware)
        - [Generics](#generics)
        - [Two-phase context model](#two-phase-context-model)
        - [Returning Reader and performing side-effects](#returning-reader-and-performing-side-effects)
        - [Dependency Injection](#dependency-injection)
        - [Middleware Examples](#middleware-examples)
        - [Middleware Bridge — declarative routing with `.on(...)`](#middleware-bridge--declarative-routing-with-on)
        - [State-driven effects — `supervise`](#state-driven-effects--supervise)
    - [Behavior](#behavior)
        - [Behavior Bridge — declarative routing with `.on(...)`](#behavior-bridge--declarative-routing-with-on)
    - [State-Driven Effects (Subscriptions)](#state-driven-effects-subscriptions)
    - [Reducer](#reducer)
- [Projection and Lifting](#projection-and-lifting)
    - [Store Projection](#store-projection-1)
    - [Lifting](#lifting)
        - [Lifting Reducer](#lifting-reducer)
        - [Lifting Behavior](#lifting-behavior)
        - [Optional transformation](#optional-transformation)
        - [Direction of the arrows](#direction-of-the-arrows)
        - [Use of KeyPaths and Prisms](#use-of-keypaths-and-prisms)
        - [Identity, Ignore and Absurd](#identity-ignore-and-absurd)

---
## Conceptual Parts
- [Action](#action)
- [State](#state)
---
### Action

An Action represents an event that was notified by external (or sometimes internal) actors of your app. It's about relevant INPUT events.

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

State represents the whole knowledge that an app holds while is open, usually in memory and mutable. It's about relevant OUTPUT properties.

There's no "State" protocol or type in SwiftRex. However, State will be found as a generic parameter for most core data structures, meaning that it's up to you to define what is the root State type.

Conceptually, we can say that state represents the whole knowledge that an app holds while is open, usually in memory and mutable; it's like a paper on where you write down some values, and for every action you receive you erase one value and replace it by a different value. Another way of thinking about state is in a functional programming way: the state is not persisted, but it's the result of a function that takes the initial condition of your app plus all the actions it received since it was launched, and calculates the current values by applying chronologically all the action changes on top of the initial state. This is known as [Event Sourcing Design Pattern](https://martinfowler.com/eaaDev/EventSourcing.html) and it's becoming popular recently in some web backend services, such as [Kafka Event Sourcing](https://kafka.apache.org/uses).

In a device with limited battery and memory we can't afford having a true event-sourcing pattern because it would be too expensive recreating the whole history of an app every time someone requests a simple boolean. So we "cache" the new state every time an action is received, and this in-memory cache is precisely what we call "State" in SwiftRex. So maybe we mix both ways of thinking about State and come up with a better generalisation for what a state is.

> **STATE** is the result of a function that takes two arguments: the previous (or initial) state and some action that occurred, to determine the new state. This happens incrementally as more and more actions arrive. State is useful for **output** data to the user.

However, be careful, some things may look like state but they are not. Let's assume you have an app that shows an item price to the user. This price will be shown as `"$3.00"` in US, or `"$3,00"` in Germany, or maybe this product can be listed in British pounds, so in US we should show `"£3.00"` while in Germany it would be `"£3,00"`. In this example we have:
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
    - [StoreType](#storetype)
    - [Real Store](#real-store)
    - [Store Projection](#store-projection)
    - [Store Buffer](#store-buffer)
    - [All together](#all-together)
- [Middleware](#middleware)
    - [Generics](#generics)
    - [Two-phase context model](#two-phase-context-model)
    - [Returning Reader and performing side-effects](#returning-reader-and-performing-side-effects)
    - [Dependency Injection](#dependency-injection)
    - [Middleware Examples](#middleware-examples)
    - [Middleware Bridge — declarative routing with `.on(...)`](#middleware-bridge--declarative-routing-with-on)
- [Behavior](#behavior)
    - [Behavior Bridge — declarative routing with `.on(...)`](#behavior-bridge--declarative-routing-with-on)
- [Reducer](#reducer)

---

### Store

#### StoreType
A protocol that defines the two expected roles of a "Store": receive/distribute actions; and publish changes of the current app state to possible subscribers. It can be a real store (such as `Store`) or just a "proxy" that acts on behalf of a real store, for example, in the case of `StoreProjection` or `StoreBuffer`.

`StoreType` is `@MainActor` and allows both class and struct conformers. It means actors can dispatch actions that will be handled by this store. These actions will eventually start side-effects or change state. These actions can also be dispatched by the result of side-effects, like the callback of an API call, or CLLocation new coordinates. How this action is handled will depend on the different implementations of `StoreType`.

`StoreType` is also a state provider, which means it's aware of certain state and can notify possible subscribers about changes. If this `StoreType` owns the state (single source-of-truth) or only proxies it from another store will depend on the different implementations of the protocol.

```
            ┌──────────┐
            │ UIButton │────────┐
            └──────────┘        │
        ┌───────────────────┐   │         dispatch<Action>(_ action: Action)
        │UIGestureRecognizer│───┼──────────────────────────────────────────────┐
        └───────────────────┘   │                                              │
            ┌───────────┐       │                                              ▼
            │viewDidLoad│───────┘                                   ┏━━━━━━━━━━━━━━━━━━━━┓
            └───────────┘                                           ┃                    ┃░
                                                                    ┃                    ┃░
                                                                    ┃                    ┃░
              ┌───────┐                                             ┃                    ┃░
              │UILabel│◀─ ─ ─ ─ ┐                                   ┃                    ┃░
              └───────┘                   Combine, RxSwift    ┌ ─ ─ ┻ ─ ┐                ┃░
                                │         or ReactiveSwift       State      Store        ┃░
       ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─│Publisher│                ┃░
       ▼               │                  subscribe(onNext:)                             ┃░
┌─────────────┐        ▼                  sink(receiveValue:) └ ─ ─ ┳ ─ ┘                ┃░
│  Diffable   │ ┌─────────────┐           assign(to:on:)            ┃                    ┃░
│ DataSource  │ │RxDataSources│                                     ┃                    ┃░
└─────────────┘ └─────────────┘                                     ┃                    ┃░
       │               │                                            ┃                    ┃░
┌──────▼───────────────▼───────────┐                                ┗━━━━━━━━━━━━━━━━━━━━┛░
│                                  │                                 ░░░░░░░░░░░░░░░░░░░░░░
│                                  │
│                                  │
│                                  │
│         UICollectionView         │
│                                  │
│                                  │
│                                  │
│                                  │
└──────────────────────────────────┘
```

There are implementations that will be the actual Store, the one and only instance that will be the central hub for the whole redux architecture. Other implementations can be only projections of the main Store, so they act like a Store by implementing the same roles, but instead of owning the global state or handling the actions directly, these projections only apply some small (and pure) transformation in the chain and delegate to the real Store. This is useful when you want to have local "stores" in your views, but you don't want them to duplicate data or own any kind of state, but only act as a store while using the central one behind the scenes.

#### Real Store

The real Store is `@MainActor final class Store<Action, State, Environment>`. You want to create it and keep it alive during the whole execution of an app, because its only responsibility is to act as a coordinator for the Unidirectional Dataflow lifecycle. That's also why we want one and only one instance of a Store. In SwiftUI you can create a store in your app protocol as a `@State`:

```swift
@main
struct MyApp: App {
    @State var store = Store(
        initial: AppState.initial,
        behavior: AppModule.behavior(environment: World.default),
        environment: World.default
    )

    var body: some Scene {
        WindowGroup {
            ContentView(store: store.projection(
                action: { (viewAction: ContentViewAction) in viewAction.toAppAction() },
                state: { ContentViewState.from(globalState: $0) }
            ).asObservableObject())
        }
    }
}
```

#### What is a Store Projection?

Very often you don't want your view to be able to access the whole App State or dispatch any possible global App Action. Not only it could refresh your UI more often than needed, it also makes more error prone, put more complex code in the view layer and finally decreases modularisation making the view coupled to the global models.

However, you don't want to split your state in multiple parts because having it in a central and unique point ensures consistency. Also, you don't want multiple separate places taking care of actions because that could potentially create race conditions. The real Store is the only place actually owning the global state and effectively handling the actions, and that's how it's supposed to be.

To solve both problems, we offer a `StoreProjection`, which is a **struct** (not a class) that conforms to the `StoreType` protocol so for all purposes it behaves like a real store, but in fact it only projects the real store using custom types for state and actions. It holds mapping closures but no state of its own — `state` is computed on every access. A `StoreProjection` has 2 closures, that allow it to transform actions and state between the global ones and the ones used by the view. That way, the View is not coupled to the whole global models, but only to tiny parts of it. This also improves performance, because the view will not refresh for any property in the global state, only for the relevant ones. On the other direction, view can only dispatch a limited set of actions, that will be mapped into global actions by the closure in the `StoreProjection`.

A Store Projection can be created from any other `StoreType`, even from another `StoreProjection`. It's as simple as calling `.projection(action:state:)`, and providing the action and state mapping closures:

```swift
let proj = store.projection(
    action: { viewAction in viewAction.toAppAction() },
    state: { globalState in MyViewState.from(globalState: globalState) }
)
```

#### Store Buffer

`StoreBuffer` provides equatable diffing — it only notifies subscribers when the projected state actually changes, avoiding unnecessary view rebuilds:

```swift
// Only rebuild views when relevant part of state changes
let buffered = store
    .projection(action: AppAction.counter, state: \.counterState)
    .buffer()  // uses Equatable conformance by default
    .asObservableObject()

// Custom predicate for non-Equatable state
let bufferedCustom = store
    .projection(action: AppAction.counter, state: \.counterState)
    .buffer { $0.count != $1.count }
    .asObservableObject()
```

SwiftUI integration:
- `.asObservableObject()` / `ObservableObjectStore` — iOS 13+, an `ObservableObject` backed by Combine
- `ViewStore` / `TrackedViewStore` — iOS 17+, `@Observable` view stores (coarse / field-level via `@Tracked`), driven by the `@Feature` macro (see [SwiftRex Architecture](#swiftrex-architecture))

#### All together

Putting everything together we could have:

```swift
@main
struct MyApp: App {
    @State var store = Store(
        initial: AppState.initial,
        behavior: AppModule.behavior(environment: World.default),
        environment: World.default
    )

    var body: some Scene {
        WindowGroup {
            ContentView(store: store.projection(
                action: { (viewAction: ContentViewAction) in viewAction.toAppAction() },
                state: { ContentViewState.from(globalState: $0) }
            ).asObservableObject())
        }
    }
}

struct ContentViewState: Equatable {
    let title: String

    static func from(globalState: AppState) -> ContentViewState {
        ContentViewState(title: "\(L10n.goodMorning), \(globalState.foo.bar.title)")
    }
}

enum ContentViewAction {
    case onAppear

    func toAppAction() -> AppAction? {
        switch self {
        case .onAppear: AppAction.foo(.bar(.startTimer))
        }
    }
}
```

In this example above we can see that `ContentView` doesn't know about the global models, it's limited to `ContentViewAction` and `ContentViewState` only. It also only refreshes when `globalState.foo.bar.title` changes, any other change in the `AppState` will be ignored because the other properties are not mapped into anything in the `ContentViewState`. Also, `ContentViewAction` has a single case, `onAppear`, and that's the only thing the view can dispatch, without knowing that this will eventually start a timer (`AppAction.foo(.bar(.startTimer))`). The view should not know about domain logic and its actions should be limited to `buttonTapped`, `onAppear`, `didScroll`, `toggle(enabled: Bool)` and other names that only suggest UI interaction. How this is mapped into App Actions is responsibility of other parts, in our example, `ContentViewAction` itself, but it could be a Presenter layer, a View Model layer, or whatever structure you decide to create to organise your code.

Testing is also made easier with this approach, as the View doesn't hold any logic and the projection transformations are pure functions.

![Store, StoreProjection and View](https://swiftrex.github.io/SwiftRex/markdown/img/StoreProjectionDiagram.png)

### Middleware

`Middleware` is a **pure struct**, not a protocol. It's a plugin, or a composition of several plugins, that are assigned to the app global `StoreType` pipeline in order to handle each action received, to execute side-effects in response, and eventually dispatch more actions in the process. It can also read the most up-to-date `State` while handling an incoming action.

We can think of a Middleware as a value that transforms actions into sync or async tasks and creates more actions as these side-effects complete, also being able to check the current state while handling an action.

An [Action](#action) is a lightweight structure, typically an enum, that is dispatched into the store.

The store enqueues a new action that arrives and submits it to a pipeline of middlewares. A `Middleware` is a struct that handles actions, and has the power to dispatch more actions, either immediately or after callback of async tasks. The middleware can also simply ignore the action, or it can execute side-effects in response, such as logging into file or over the network, or execute http requests. In case of those async tasks, when they complete the middleware can dispatch new actions containing a payload with the response. Other middlewares will handle that, or maybe even the same middleware in the future, or perhaps some `Reducer` will use this action to change the state, because the `Middleware` itself can never change the state, only read it.

The `handle` function will be called before the Reducer, so if you read the state at that point it's still going to be the unchanged version. While implementing this function, it.s expected that you return the effect `Reader<PostReducerContext<State, Environment>, Effect<Action>>` — a description of the side-effects to run once the post-mutation context (including the environment) is available. Inside this Reader closure, the state will have the new values after the reducers handled the current action, so in case you made a copy of the old state, you can compare them, log, audit, perform analytics tracking, telemetry or state sync with external devices, such as Apple Watches.

Every action dispatched also comes with its action source, which is the primary dispatcher of that action. Middlewares can access the file name, line of code, function name and additional information about the entity responsible for creating and dispatching that action, which is a very powerful debugging information that can help developers to trace how the information flows through the app.

Ideally a `Middleware` should be a small and reusable box, handling only a very limited set of actions, and combined with other small middlewares to create more complex apps. For example, the same `CoreLocation` middleware could be used from an iOS app, its extensions, the Apple Watch extension or even different apps, as long as they share some sub-action tree and sub-state struct.

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
- `RxSwift` observables, `ReactiveSwift` signal producers, `Combine` publishers, `AsyncSequence`
- Observation of traits changes, device rotation, language/locale, dark mode, dynamic fonts, background/foreground state
- Any side-effect, I/O, networking, sensors, third-party libraries that you want to abstract

```
                                                                                                                    ┌────────┐                                     
                                                       Effect closure                                             ┌─▶│ View 1 │                                     
                      ┌─────┐                          (run later)                            ┌─────┐             │  └────────┘                                     
                      │     │ handle  ┌──────────┐  ┌───────────────────────────────────────▶│     │ send        │  ┌────────┐                                     
                      │     ├────────▶│Middleware│──┘                                        │     │────────────▶├─▶│ View 2 │                                     
                      │     │ Action  │ Pipeline │──┐  ┌─────┐ reduce ┌──────────┐           │     │ New state   │  └────────┘                                     
                      │     │         └──────────┘  └─▶│     │───────▶│ Reducer  │──────────▶│     │             │  ┌────────┐                                     
    ┌──────┐ dispatch │     │                          │Store│ Action │ Pipeline │ New state │     │             └─▶│ View 3 │                                     
    │Button│─────────▶│Store│                          │     │ +      └──────────┘           │Store│                └────────┘                                     
    └──────┘ Action   │     │                          └─────┘ State                         │     │                                   dispatch    ┌─────┐         
                      │     │                                                                │     │       ┌─────────────────────────┐ New Action  │     │         
                      │     │                                                                │     │─run──▶│      Effect closure     ├────────────▶│Store│─ ─ ▶ ...
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

Middleware is generic over 3 type parameters:

- **Action**:

    The Action type that this `Middleware` knows how to handle. Most of the times middlewares don't need to handle all possible actions from the whole global action tree, so we can decide to allow it to focus only on a subset of the action.

    In this case, this action type can be a subset to be lifted to a global action type in order to compose with other middlewares acting on the global action of an app. Please check [Lifting](#lifting) for more details.

- **State**:

    The State part that this `Middleware` needs to read in order to make decisions. This middleware will receive a `PreReducerContext<State>` in phase 1 (before mutation) and a `PostReducerContext<State, Environment>` in phase 3 (after mutation), but it can never write or mutate the state.

    Most of the times middlewares don't need reading the whole global state, so we can decide to allow it to read only a subset of the state, or maybe this middleware doesn't need to read any state, so the `State` can safely be set to `Void`.

    In this case, this state type can be a subset to be lifted to a global state in order to compose with other middlewares acting on the global state of an app. Please check [Lifting](#lifting) for more details.

- **Environment**:

    The dependency type that this `Middleware` needs to perform its work. Dependencies are injected via the `Reader` wrapper at call time, so you never store them on the middleware itself.

#### Two-phase context model

`Middleware.handle` receives two arguments:

- `action: Action` — the action being dispatched (plain value, no wrapper needed).
- `context: PreReducerContext<State>` — a `@MainActor`, **non-`Sendable`** snapshot of pre-mutation state; holds `context.stateBefore: State?` and `context.source: ActionSource`.

It returns `Reader<PostReducerContext<State, Environment>, Effect<Action>>`. The `Reader` closure runs in phase 3, after mutations, and receives a `PostReducerContext<State, Environment>` with:

- `ctx.environment: Environment` — dependencies injected at that point.
- `ctx.liveState: State?` — post-mutation state; requires `@MainActor`. From a non-`@MainActor` context use `await MainActor.run { ctx.liveState }`, or the `readLiveState()` helper described below.

`PreReducerContext` is **non-Sendable by design** — the compiler prevents you from capturing it into the `@Sendable` phase-3 closure. If you need to compare before/after, capture `context.stateBefore` into a local `let` first.

**Reading post-mutation state from a reactive pipeline** — `SwiftRex.Combine`, `SwiftRex.RxSwift`, `SwiftRex.ReactiveSwift`, and `SwiftRex.ReactiveConcurrency` each add a `readLiveState()` extension on `PostReducerContext` that returns a single-element stream and hops to `@MainActor` automatically:

```swift
// Combine (AnyPublisher)
return .produce { ctx in
    ctx.readLiveState()                                     // AnyPublisher<State, Never>
        .flatMap { state in ctx.environment.api.save(state.draft) }
        .asEffect()
}

// RxSwift (Observable)
return .produce { ctx in
    ctx.readLiveState()                                     // Observable<State>
        .flatMap { state in ctx.environment.api.save(state.draft) }
        .asEffect()
}

// ReactiveSwift (SignalProducer)
return .produce { ctx in
    ctx.readLiveState()                                     // SignalProducer<State, Never>
        .flatMap(.latest) { state in ctx.environment.api.save(state.draft) }
        .asEffect()
}

// ReactiveConcurrency (Publisher)
return .produce { ctx in
    ctx.readLiveState()                                     // Publisher<State, Never>
        .flatMap { state in ctx.environment.api.save(state.draft) }
        .asEffect()
}
```

The state is read lazily — only when a subscriber attaches — so it always reflects the post-mutation value from the current dispatch cycle.

#### Returning Reader and performing side-effects

SwiftRex defines two conveniences on `Reader<PostReducerContext<State, Environment>, Effect<Action>>` that mirror the fluent API available in `Reaction`:

```swift
// No effect — skip early
guard case .myAction = action else { return .doNothing }

// Produce an effect with environment access
return .produce { ctx in
    Effect.task { .result(await ctx.environment.api.fetch()) }
}
```

`.doNothing` is equivalent to `Reader { _ in .empty }`. `.produce` is equivalent to `Reader { ctx in … }`. Either form is acceptable; the named versions communicate intent more clearly at the call site.

#### Dependency Injection

Testability is one of the most important aspects to account for when developing software. In Redux architecture, `Middleware` is the only type of object allowed to perform side-effects, so it's the only place where the testability can be challenging.

To improve testability, the middleware should use as few external dependencies as possible. If it starts to use too many, consider splitting in smaller middlewares, this will also protect you against race conditions and other problems, will help with tests and make the middleware more reusable.

All external dependencies are injected through the produce `Reader<PostReducerContext<State, Environment>, Effect<Action>>` return type, reachable as `ctx.environment`. This means during tests you provide a mock `Environment` and the middleware never stores dependencies as properties — they are provided fresh every time an action is handled. If your middleware uses only one call from a very complex object, consider injecting a closure or a focused protocol instead of the full concrete type.

#### Middleware Examples

When implementing your Middleware, all you have to do is handle the incoming actions:

```swift
// Logger: capture pre-mutation state in phase 1, compare with post-mutation state in phase 3
let loggerMiddleware = Middleware<AppAction, AppState, Logger>.handle { action, context in
    let stateBefore = context.stateBefore          // phase 1 — pre-mutation state
    let source = "\(context.source.file):\(context.source.line)"
    return Reader { ctx in
        let liveState = ctx.liveState              // phase 3 — post-mutation state
        ctx.environment.log(action: action, from: source, before: stateBefore, after: liveState)
        return .empty
    }
}

// Favorites: read state before mutation, then call the API in phase 3
let favoritesMiddleware = Middleware<FavoritesAction, FavoritesModel, API>.handle { action, context in
    guard case let .toggleFavorite(movieId) = action else { return .doNothing }
    let currentList = context.stateBefore          // capture before any mutation
    let makeFavorite = !(currentList?.contains(where: { $0.id == movieId }) ?? false)
    return .produce { ctx in
        Effect.task {
            let result = await ctx.environment.changeFavorite(id: movieId, makeFavorite: makeFavorite)
            return .changedFavorite(movieId, isFavorite: result)
        }
    }
}
```

#### Middleware Bridge — declarative routing with `.on(...)`

Instead of writing a `handle` closure for simple action-routing middlewares, use the `.on(...)` builder methods. They compose onto any existing `Middleware` value via `.combine` and cover 12 patterns across three families — Prism, KeyPath, and Bool predicate. State is **never copied** unless the action filter passes first.

```swift
// Start from identity and chain .on(...) calls
let bridge = Middleware<AppAction, AppState, World>.identity
    // — Prism family —
    // 1. Prism + dispatch closure
    .on(AppAction.prism.didSearch, dispatch: AppAction.performSearch)
    // 2. Prism + dispatch + state guard (state read only if prism matches)
    .on(AppAction.prism.didTapBuy, dispatch: AppAction.checkout, when: { $0.isLoggedIn })
    // 3. Prism pair (same payload T — no dispatch: label)
    .on(AppAction.prism.searchQuery, AppAction.prism.updateSearch)
    // 5. Void prism → fixed action
    .on(AppAction.prism.didTapLogout, dispatch: AppAction.auth(.logout))
    // — KeyPath family —
    // 7. KeyPath (macro-generated enum case property)
    .on(\.didSearch, dispatch: AppAction.performSearch)
    // 9. Void key path → fixed action
    .on(\.didTapLogout, dispatch: AppAction.auth(.logout))
    // — Bool predicate family —
    // 11. Bool predicate + fixed dispatch (no state ever read)
    .on({ case .reset = $0 }, dispatch: .clearAll)
    // 12. Bool predicate + fixed dispatch + state guard
    .on({ case .retry = $0 }, dispatch: .reload, when: { $0.retryCount < 3 })
```

All `when:` variants read state only after the action filter passes; unmatched actions never touch the store's state.

#### State-driven effects — `supervise`

`.produce` is the *action-driven* half of a middleware (`Cmd`). A middleware also carries a *state-driven* half (`Sub`): `.supervise` maps the **state** to a `Supervision` — the long-lived `Channel`s to `keep` alive while that state holds — a socket, a timer, a poll, a `CoreLocation`/`HealthKit` delegate, a database observer. Several of the "suggested middlewares" above (Timers, database subscriptions, WebSockets, location) are state-driven and belong here rather than in a `.produce`:

```swift
let location = Middleware<AppAction, AppState, World>
    .supervise { state in
        Supervision { env in
            guard state.isTrackingLocation else { return [] }   // stop tracking → stream cancelled
            return [Channel(id: "location") { dispatch in
                let mgr = env.startLocationUpdates(); mgr.onUpdate { dispatch(.located($0)) }
                return .cancelOnly { mgr.stop() }
            }]
        }
    }
```

`combine` unions the supervisors of both middlewares, and `asBehavior` carries the axis through. See **[State-Driven Effects](#state-driven-effects-subscriptions)** for the full model.

---

### Behavior

`Behavior` is the primary composition unit in SwiftRex. It fuses a `Reducer`, a `Middleware`, and a state-driven supervisor into a single, liftable, composable value. When building your app module, you typically create a `Behavior` rather than wiring those parts separately.

A feature has up to **three independent concerns**, and `Behavior` gives each its own fluent builder. Each exists as a static factory (`Behavior.reduce { … }`) *and* as an instance method (`someBehavior.produce { … }`), so a chain is exactly a `<>` fold of single-concern behaviors:

```swift
let room = Behavior<RoomAction, RoomState, RoomEnv>
    .reduce { action, state in … }    // what changes — a pure (Action, inout State) -> Void
    .produce { action, ctx in … }     // do because of an action — an Effect (Elm's Cmd)
    .supervise { state in … }         // keep alive while the state holds — Channels to keep (Elm's Sub)
```

| Axis | Builder | Cause | Returns | Store does |
|---|---|---|---|---|
| State change | `.reduce` | an action | an `inout` mutation | mutates |
| Action-driven effect | `.produce` | an action | an `Effect` | performs |
| State-driven effect | `.supervise` | the **state** | a `Supervision` → `Keep` (`[Channel]`) | keeps |

The first two are the *action-driven* side (something happened, so change state / run an effect). `.supervise` is the *state-driven* side: a long-lived resource — a socket, a timer, a poll — that exists for as long as the state implies it, with *leaving that state* as the teardown. See **[State-Driven Effects](#state-driven-effects-subscriptions)** below.

There are also three lower-level creation paths:

```swift
// 1. Direct — a whole Reaction in one shot (no separate Reducer or Middleware needed)
let counterBehavior = Behavior<CounterAction, CounterState, Void>.react { action, _ in
    switch action {
    case .increment: return .reduce { $0.count += 1 }
    case .decrement: return .reduce { $0.count -= 1 }
    case .fetch(let query): return .produce { _ in apiEffect(query) }
    }
}

// 2. From a Reducer alone
let reducerBehavior: Behavior<CounterAction, CounterState, Void> = counterReducer.asBehavior()

// 3. From an existing Reducer + Middleware pair (the Middleware's supervise axis carries through)
let fullBehavior = Behavior(reducer: counterReducer, middleware: loggingMiddleware)
```

The grouped `.react` builder (alias `.handle`) takes the same two arguments as `Middleware.handle` (`action` and a pre-mutation `PreReducerContext<State>`) and returns a `Reaction` — the action-driven outcome:

```swift
.doNothing                                  // no mutation, no effect
.reduce { $0.x += 1 }                      // mutation only
.produce { ctx in ... }                       // effect only (ctx: PostReducerContext<State, Environment>)
.reduce { $0.x += 1 }.produce { ctx in ... }  // both mutation and effect
```

Behaviors compose with `<>`:

```swift
let appBehavior = counterBehavior <> authBehavior <> networkBehavior
```

#### Behavior Bridge — declarative routing with `.on(...)`

`Behavior` has the same `.on(...)` builder methods as `Middleware`, plus an optional `reduce:` parameter that lets you co-locate the state mutation with the routing. There are 28 variants across four families. State is **never copied** unless the action filter passes first; if neither `reduce:` nor `when:` is provided, `mutation` is `.identity` — state is never passed by inout reference at all, guaranteeing zero CoW interaction.

Prism/KeyPath overloads come in two distinct forms: without `reduce:` (uses `mutation: .identity`) and with `reduce:` (required, no default). Use the dispatch-only form when you have no mutation to co-locate — it's structurally zero-cost, not just documented as such.

```swift
let behavior = Behavior<AppAction, AppState, World>.identity
    // — Prism family (variants 1–12) —
    // 1. Prism + dispatch only — mutation: .identity, no state interaction
    .on(AppAction.prism.didLoad, dispatch: AppAction.renderItems)
    // 2. Prism + dispatch + state guard — mutation: .identity, one copy for condition
    .on(AppAction.prism.didTapBuy, dispatch: AppAction.checkout, when: { $0.isLoggedIn })
    // 3. Prism + dispatch + reduce (required)
    .on(AppAction.prism.didLoad,
        dispatch: AppAction.renderItems,
        reduce: { items, state in state.items = items; state.isLoading = false })
    // 4. Prism + dispatch + reduce + state guard
    .on(AppAction.prism.didTapBuy, dispatch: AppAction.checkout,
        reduce: { _, state in state.isCheckingOut = true },
        when: { $0.isLoggedIn })
    // 9. Void prism + dispatch only
    .on(AppAction.prism.didTapLogout, dispatch: AppAction.auth(.logout))
    // 11. Void prism + dispatch + reduce (required)
    .on(AppAction.prism.didTapLogout,
        dispatch: AppAction.auth(.logout),
        reduce: { state in state.isLoggingOut = true })
    // — KeyPath family (variants 13–20) —
    // 13. KeyPath + dispatch only — mutation: .identity, no state interaction
    .on(\.didLoad, dispatch: AppAction.renderItems)
    // 14. KeyPath + dispatch + state guard — mutation: .identity, one copy for condition
    .on(\.didTapBuy, dispatch: AppAction.checkout, when: { $0.isLoggedIn })
    // 15. KeyPath + dispatch + reduce (required)
    .on(\.didLoad,
        dispatch: AppAction.renderItems,
        reduce: { items, state in state.items = items; state.isLoading = false })
    // 17. Void key path + dispatch only
    .on(\.didTapLogout, dispatch: AppAction.auth(.logout))
    // 19. Void key path + dispatch + reduce (required)
    .on(\.didTapLogout,
        dispatch: AppAction.auth(.logout),
        reduce: { state in state.isLoggingOut = true })
    // — Bool predicate family (variants 21–26) —
    // 21. Predicate + fixed dispatch — no state ever read
    .on({ case .reset = $0 }, dispatch: .clearAll)
    // 22. Predicate + state guard (state read only if predicate matches)
    .on({ case .retry = $0 }, dispatch: .reload, when: { $0.retryCount < 3 })
    // 23. Predicate + mutation only (no dispatch)
    .on({ case .toggle = $0 }, reduce: { $0.isActive.toggle() })
    // 24. Predicate + mutation + dispatch
    .on({ case .didLoad = $0 }, reduce: { $0.isLoading = false }, dispatch: .renderItems)
    // 25. Predicate + mutation + guard (no dispatch)
    .on({ case .submit = $0 }, reduce: { $0.isSubmitting = true }, when: { !$0.isSubmitting })
    // 26. Predicate + mutation + dispatch + guard — full
    .on({ case .submit = $0 },
        reduce: { $0.isSubmitting = true },
        dispatch: .doSubmit,
        when: { !$0.isSubmitting })
    // — Pure routing, no mutation (variants 27–28) —
    // 27. (Action) -> Action? — derived dispatch, no state
    .on { action in
        guard case .didSearch(let q) = action else { return nil }
        return .performSearch(q)
    }
```

All `when:` variants read state only after the action filter passes; unmatched actions never touch the store's state. Variants without `reduce:` and without `when:` have zero state interaction — not even an inout reference is taken.

---

### State-Driven Effects (Subscriptions)

Most side-effects are **action-driven**: *this happened, so do that.* A `.search` fires a request; the request finishes. That's `.produce`, returning an `Effect` — Elm's `Cmd`.

But some effects shouldn't be started by an action at all — they should exist *for as long as the state says so*. A socket stays open **while a room is joined**; a timer ticks **while a screen is visible**; a poll runs **while a query is set**. No single action starts or stops them — the *state* implies them, and **leaving that state is the teardown**. That's `.supervise`, returning a `Supervision` of `Channel`s to keep — Elm's `Sub`.

```swift
let room = Behavior<RoomAction, RoomState, RoomEnv>
    .reduce { action, state in
        switch action {
        case .join(let id):    state.joinedRoom = id
        case .leave:           state.joinedRoom = nil
        case .received(let m): state.messages.append(m)
        }
    }
    .supervise { state in
        Supervision { env in
            guard let id = state.joinedRoom else { return [] }   // no room → no socket
            return [Channel(id: id) { dispatch in
                let socket = env.connect(id)
                socket.onMessage { dispatch(.received($0)) }     // events out → actions
                return ChannelHandler(receive: { socket.write($0) },   // values in → the resource
                                      cancel:  { socket.close() })      // teardown, written once
            }]
        }
    }
```

When `joinedRoom` becomes `nil`, the supervision returns `[]`, the engine sees the socket is no longer desired, and closes it. You never wired `socket.close()` to `.leave` — *leaving the state that implied the socket cancels it.*

#### How it runs

After every state mutation the `Store` recomputes the whole desired set (`supervise(state)`) and **reconciles** it against what's running: channels newly present **open**, channels now absent **cancel**, channels still present are **left untouched** — an unchanged desired set produces *zero* operations. Because the desired set is a pure function of state, it survives time-travel and redelivery. Two knobs drive the diff:

- **`Channel.Lifetime`** — `.permanent` (default) keeps it open; `.ephemeral(resetKey:)` **recreates** it (close + reopen) when the key changes — reconnect a socket when the room changes, restart a poll when the query changes. Add `settle:` to **debounce the recreation** (tear down now, reopen once the key is quiet) — search-as-you-type reconnection without thrashing.
- **`Channel.Broadcasting`** — `.nothing` (default) opens without delivering; `.onChange(value)` auto-publishes a *state-derived* value on open and whenever it changes, deduped.
- **`ChannelDelivery`** — paces the *values* into a live channel (`.throttle`/`.debounce`), the channel acting as a throttled subject. Creation is decoupled from delivery: the channel always **opens immediately**; only the values are paced (and an `ephemeral` recreate resets the window).

For *discrete, action-driven* sends into a live channel, a `.produce` returns `Effect.broadcast(_:channel:)` — it rendezvous with the supervised channel on the shared id (the *send* half of a two-way socket; the chat example below). `Effect.open(_:)` and `Effect.cancel(id:)` let you own a channel's lifetime by hand when it genuinely isn't a function of state.

`Middleware` carries the same `.supervise` axis, and **every lift threads it through** — `liftState` focuses channels onto a sub-state (state-driven nav: sub-state gone ⇒ its channels cancel), `liftCollection`/`liftEach` fan a per-element feature's channels across a collection with per-element id stamping. Duplicate identical channels (e.g. a `liftEach` and a `liftCollection` on one collection) are **deduped** by the reconciler, so it never double-opens.

Already have the stream as a publisher or async sequence? The companion bridges turn one straight into a channel — `publisher.asChannel(id:, AppAction.case)` (Combine, RxSwift, ReactiveSwift, ReactiveConcurrency) and `asyncSequence.asChannel(id:, AppAction.case)` (SwiftConcurrency) — the `asChannel` counterpart of `asEffect`. A source that emits synchronously on subscription is delivered safely: every channel dispatch hops onto a later turn, so the value is deferred rather than re-entering the reconcile that opened the channel.

#### Worked examples

Full, compiling walkthroughs live in the DocC catalog and are deep-linked here:

| Example | Demonstrates |
|---|---|
| [**Timer**](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/exampletimer) | `supervise` + `.ephemeral(resetKey:)` (recreate on interval change) + `.cancelOnly` |
| [**Polling**](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/examplepolling) | `Supervision` reading the environment, restart-on-query via `resetKey`, results as actions |
| [**Chat room**](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/examplechatroom) | the two-way rendezvous — `supervise` keeps the socket, `.produce` + `Effect.broadcast` sends |
| [**WebSocket**](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/examplewebsocket) | reconnect on token change (`Lifetime`) vs. push presence (`Broadcasting.onChange`) |

Concepts: **[State-Driven Effects](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/statedriveneffects)** · **[Channels](https://swiftrex.github.io/SwiftRex/documentation/swiftrex/channels)** (the `Channel` / `ChannelHandler` / `Keep` API).

---

### Reducer

`Reducer` is a pure function wrapped in a monoid container, that takes an action and the current state to calculate the new state.

The `Middleware` pipeline can do two things: dispatch outgoing actions and handle incoming actions. But what they can NOT do is change the app state. Middlewares have read-only access to the up-to-date state of our apps, but when mutations are required we use the `MutableReduceFunction`:

```swift
(ActionType, inout StateType) -> Void
```

Which has the same semantics (but better performance) than the old `ReduceFunction`:

```swift
(ActionType, StateType) -> StateType
```

Given an action and the current state (as a mutable inout), it calculates the new state and changes it:

```
initial state is 42
action: increment
reducer: increment 42 => new state 43

current state is 43
action: decrement
reducer: decrement 43 => new state 42

current state is 42
action: half
reducer: half 42 => new state 21
```

The function is reducing all the actions in a cached state, and that happens incrementally for each new incoming action.

It's important to understand that reducer is a synchronous operation that calculates a new state without any kind of side-effect (including non-obvious ones as creating `Date()`, using DispatchQueue or `Locale.current`), so never add properties to the `Reducer` structs or call any external function. If you are tempted to do that, please create a middleware and dispatch actions with Dates or Locales from it.

Reducers are also responsible for keeping the consistency of a state, so it's always good to do a final sanity check before changing the state, like for example check other dependent properties that must be changed together.

Once the reducer function executes, the store will update its single source-of-truth with the new calculated state, and propagate it to all its subscribers, that will react to the new state and update Views, for example.

This function is wrapped in a struct to overcome some Swift limitations, for example, allowing us to compose multiple reducers into one (monoid operation, where two or more reducers become a single one) or lifting reducers from local types to global types.

The ability to lift reducers allow us to write fine-grained "sub-reducer" that will handle only a subset of the state and/or action, place it in different frameworks and modules, and later plugged into a bigger state and action handler by providing a way to map state and actions between the global and local ones. For more information about that, please check [Lifting](#lifting).

A possible implementation of a reducer would be:
```swift
let volumeReducer = Reducer<VolumeAction, VolumeState>.reduce { action, currentState in
    switch action {
    case .louder:
        currentState = VolumeState(
            isMute: false, // When increasing the volume, always unmute it.
            volume: min(100, currentState.volume + 5)
        )
    case .quieter:
        currentState = VolumeState(
            isMute: currentState.isMute,
            volume: max(0, currentState.volume - 5)
        )
    case .toggleMute:
        currentState = VolumeState(
            isMute: !currentState.isMute,
            volume: currentState.volume
        )
    }
}
```

Please notice from the example above the following good practices:
- No `DispatchQueue`, threading, operation queue, promises, reactive code in there.
- All you need to implement this function is provided by the arguments `action` and `currentState`, don't use any other variable coming from global scope, not even for reading purposes. If you need something else, it should either be in the state or come in the action payload.
- Do not start side-effects, requests, I/O, database calls.
- Avoid `default` when writing `switch`/`case` statements. That way the compiler will help you more.
- Make the action and the state generic parameters as much specialised as you can. If volume state is part of a bigger state, you should not be tempted to pass the whole big state into this reducer. Make it short, brief and specialised, this also helps preventing `default` case or having to re-assign properties that are never mutated by this reducer.

```
                                                                                                                    ┌────────┐                                     
                                                       Effect closure                                             ┌─▶│ View 1 │                                     
                      ┌─────┐                          (run later)                            ┌─────┐             │  └────────┘                                     
                      │     │ handle  ┌──────────┐  ┌───────────────────────────────────────▶│     │ send        │  ┌────────┐                                     
                      │     ├────────▶│Middleware│──┘                                        │     │────────────▶├─▶│ View 2 │                                     
                      │     │ Action  │ Pipeline │──┐  ┌─────┐ reduce ┌──────────┐           │     │ New state   │  └────────┘                                     
                      │     │         └──────────┘  └─▶│     │───────▶│ Reducer  │──────────▶│     │             │  ┌────────┐                                     
    ┌──────┐ dispatch │     │                          │Store│ Action │ Pipeline │ New state │     │             └─▶│ View 3 │                                     
    │Button│─────────▶│Store│                          │     │ +      └──────────┘           │Store│                └────────┘                                     
    └──────┘ Action   │     │                          └─────┘ State                         │     │                                   dispatch    ┌─────┐         
                      │     │                                                                │     │       ┌─────────────────────────┐ New Action  │     │         
                      │     │                                                                │     │─run──▶│      Effect closure     ├────────────▶│Store│─ ─ ▶ ...
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

## Projection and Lifting
- [Store Projection](#store-projection-1)
- [Lifting](#lifting)
    - [Lifting Reducer](#lifting-reducer)
    - [Lifting Behavior](#lifting-behavior)
    - [Optional transformation](#optional-transformation)
    - [Direction of the arrows](#direction-of-the-arrows)
    - [Use of KeyPaths and Prisms](#use-of-keypaths-and-prisms)
    - [Identity, Ignore and Absurd](#identity-ignore-and-absurd)

### Store Projection

An app should have a single real Store, holding a single source-of-truth. However, we can "derive" this store to small subsets, called store projections, that will handle either a smaller part of the state or action tree, or even a completely different type of actions and states as long as we can map back-and-forth to the original store types. It won't store anything, only project the original store. For example, a View can define a completely custom View State and View Action, and we can create a `StoreProjection` that works on these types, as long as it's backed by a real store which State and Action types can be mapped somehow to the View State and View Action types. The Store Projection will take care of translating these entities.

![Store Projection](https://swiftrex.github.io/SwiftRex/markdown/img/StoreProjectionDiagram.png)

Very often you don't want your view to be able to access the whole App State or dispatch any possible global App Action. Not only it could refresh your UI more often than needed, it also makes more error prone, puts more complex code in the view layer and finally decreases modularisation making the view coupled to the global models.

However, you don't want to split your state in multiple parts because having it in a central and unique point ensures consistency. Also, you don't want multiple separate places taking care of actions because that could potentially create race conditions. The real Store is the only place actually owning the global state and effectively handling the actions, and that's how it's supposed to be.

To solve both problems, we offer a `StoreProjection` (a struct), which conforms to the `StoreType` protocol so for all purposes it behaves like a real store, but in fact it only projects the real store using custom types for state and actions. A `StoreProjection` has 2 closures, that allow it to transform actions and state between the global ones and the ones used by the view. That way, the View is not coupled to the whole global models, but only to tiny parts of it. This also improves performance, because the view will not refresh for any property in the global state, only for the relevant ones. On the other direction, view can only dispatch a limited set of actions, that will be mapped into global actions by the closure in the `StoreProjection`.

A Store Projection can be created from any other `StoreType`, even from another `StoreProjection`. It's as simple as calling `.projection(action:state:)`, and providing the action and state mapping closures:

```swift
let proj = store.projection(
    action: { viewAction in viewAction.toAppAction() },
    state: { globalState in MyViewState.from(globalState: globalState) }
).asObservableObject()
```

### Lifting

An app can be a complex product, performing several activities that not necessarily are related. For example, the same app may need to perform a request to a weather API, check the current user location using CLLocation and read preferences from UserDefaults.

Although these activities are combined to create the full experience, they can be isolated from each other in order to avoid URLSession logic and CLLocation logic in the same place, competing for the same resources and potentially causing race conditions. Also, testing these parts in isolation is often easier and leads to more significant tests.

Ideally we should organise our `AppState` and `AppAction` to account for these parts as isolated trees. In the example above, we could have 3 different properties in our AppState and 3 different enum cases in our AppAction to group state and actions related to the weather API, to the user location and to the UserDefaults access.

This gets even more helpful in case we split our app in 3 types of `Reducer` and 3 types of `Middleware`, and each of them work not on the full `AppState` and `AppAction`, but in the 3 paths we grouped in our model. The first pair of `Reducer` and `Middleware` would be generic over `WeatherState` and `WeatherAction`, the second pair over `LocationState` and `LocationAction` and the third pair over `RepositoryState` and `RepositoryAction`. They could even be in different frameworks, so the compiler will forbid us from coupling Weather API code with CLLocation code, which is great as this enforces better practices and unlocks code reusability. Maybe our CLLocation middleware/reducer can be useful in a completely different app that checks for public transport routes.

But at some point we want to put these 3 different types of entities together, and the `StoreType` of our app "speaks" `AppAction` and `AppState`, not the subsets used by the specialised handlers.

```swift
enum AppAction {
    case weather(WeatherAction)
    case location(LocationAction)
    case repository(RepositoryAction)
}
struct AppState {
    let weather: WeatherState
    let location: LocationState
    let repository: RepositoryState
}
```

Given a reducer that is generic over `WeatherAction` and `WeatherState`, we can "lift" it to the global types `AppAction` and `AppState` by telling this reducer how to find in the global tree the properties that it needs. That would be `AppAction.prism.weather` and `\AppState.weather`. The same can be done for the middleware (or behavior), and for the other 2 reducers and middlewares of our app.

When all of them are lifted to a common type, they can be combined together using the diamond operator (`<>`) and set as the store handler.

> **_IMPORTANT:_** Because enums in Swift don't have KeyPath as structs do, we strongly recommend reading [Action Enum Properties](docs/markdown/ActionEnumProperties.md) document and implementing properties for each case, either manually or using code generators, so later you avoid writing lots and lots of error-prone switch/case. We also offer some templates to help you on that.

Let's explore how to lift reducers and behaviors.

#### Lifting Reducer

`Reducer` has AppAction INPUT, AppState INPUT and AppState OUTPUT, because it can only handle actions (never dispatch them), read the state and write the state.

The lifting direction, therefore, should be:
```
Reducer:
- ReducerAction? ← AppAction
- ReducerState ←→ AppState
```

Given:
```swift
//      type 1         type 2
Reducer<ReducerAction, ReducerState>
```

Transformations:
```
                                                                                 ╔═══════════════════╗
                                                                                 ║                   ║
                       ╔═══════════════╗                                         ║                   ║
                       ║    Reducer    ║ .lift                                   ║       Store       ║
                       ╚═══════════════╝                                         ║                   ║
                               │                                                 ║                   ║
                                                                                 ╚═══════════════════╝
                               │                                                           │          
                                                                                                      
                               │                                                           │          
                                                                                     ┌───────────┐    
                         ┌─────┴─────┐   (AppAction) -> ReducerAction?               │           │    
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐    │  Reducer  │   AppAction.prism.case?.reducerAction         │           │    
    Input Action         │  Action   │◀──────────────────────────────────────────────│ AppAction │    
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘    │           │   Prism<AppAction, ReducerAction>             │           │    
                         └─────┬─────┘   AppAction.prism.reducerAction               │           │    
                                                                                     └───────────┘    
                               │                                                           │          
                                                                                                      
                               │         get: (AppState) -> ReducerState                   │          
                                         { $0.reducerState }                         ┌───────────┐    
                         ┌─────┴─────┐   set: (inout AppState, ReducerState) -> Void │           │    
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐    │  Reducer  │   { $0.reducerState = $1 }                    │           │    
        State            │   State   │◀─────────────────────────────────────────────▶│ AppState  │    
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘    │           │   WritableKeyPath<AppState, ReducerState>     │           │    
                         └─────┬─────┘   \AppState.reducerState                      │           │    
                                                                                     └───────────┘    
                               │                                                           │          
```

Lifting a Reducer:
```swift
// Using Prism for action, WritableKeyPath for state:
volumeReducer.lift(
    action: AppAction.prism.volume,    // Prism<AppAction, VolumeAction>
    state: \AppState.volume            // WritableKeyPath<AppState, VolumeState>
)
```

Or using closures:
```swift
volumeReducer.lift(
    actionGetter: { (action: AppAction) -> VolumeAction? in action.prism?.volume },
    stateGetter: { (state: AppState) -> VolumeState in state.volume },
    stateSetter: { (state: inout AppState, newValue: VolumeState) in state.volume = newValue }
)
```

#### Lifting Behavior

`Behavior` can be lifted in the same way, and it's the preferred approach when you have both mutation and effects in a single unit:

```swift
// Using Prism for action (both input filter and output wrap):
counterBehavior.liftAction(AppAction.prism.counter)

// Using WritableKeyPath for state:
counterBehavior.liftState(\AppState.counter)

// Combined:
counterBehavior.lift(
    action: AppAction.prism.counter,
    state: \AppState.counter,
    environment: { $0.counterService }
)
```

Note that action lifting for `Behavior` and `Middleware` always uses a `Prism` or `AffineTraversal` — never a `WritableKeyPath`, because actions are never writable from the middleware's perspective.

**Collections.** `liftCollection(action:embed:stateCollection:)` runs a per-element feature against one element of a collection (selected by id), and `liftEach(...)` broadcasts to every element. Both rewrite each element's effect-scheduling ids to be element-scoped, so element A's `.debounce(id: .fetch)` never cancels element B's.

**Lifting carries all three axes — including `supervise`.** A lifted feature keeps its state-driven channels: `liftState` focuses them onto a sub-state (so when the sub-state disappears — e.g. you navigate away — its channels are reconciled away and cancelled), `liftAction` re-embeds their dispatched actions, `liftEnvironment` adapts their dependencies, and the collection lifts fan a feature's channels across every element with **per-element id stamping** (element A's `"socket"` ≠ element B's `"socket"`). Identical channels produced by more than one lift are deduped by the reconciler. This is what makes state-driven navigation work: model your routes as state, and the channels each screen needs come and go with it. See **[State-Driven Effects](#state-driven-effects-subscriptions)**.

Lifting direction for Middleware/Behavior:
```
Middleware/Behavior:
- MiddlewareInputAction? ← AppAction
- MiddlewareOutputAction → AppAction
- MiddlewareState ← AppState
```

Transformations:
```
                                                                                 ╔═══════════════════╗
                                                                                 ║                   ║
                       ╔═══════════════╗                                         ║                   ║
                       ║  Middleware   ║ .lift                                   ║       Store       ║
                       ╚═══════════════╝                                         ║                   ║
                               │                                                 ║                   ║
                                                                                 ╚═══════════════════╝
                               │                                                           │          
                                                                                                      
                               │                                                           │          
                                                                                     ┌───────────┐    
                         ┌─────┴─────┐   (AppAction) -> MiddlewareInputAction?       │           │    
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐    │Middleware │   AppAction.prism.middlewareAction            │           │    
    Input Action         │   Input   │◀──────────────────────────────────────────────│ AppAction │    
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘    │  Action   │   Prism<AppAction, MiddlewareInputAction>     │           │    
                         └─────┬─────┘                                               │           │    
                                                                                     └───────────┘    
                               │                                                     ┌─────┴─────┐    
                         ┌───────────┐   (MiddlewareOutputAction) -> AppAction       │           │    
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐    │Middleware │   { AppAction.case($0) }                      │           │    
    Output Action        │  Output   │──────────────────────────────────────────────▶│ AppAction │    
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘    │  Action   │   AppAction.case                              │           │    
                         └───────────┘                                               │           │    
                               │                                                     └─────┬─────┘    
                                                                                     ┌───────────┐    
                         ┌─────┴─────┐   (AppState) -> MiddlewareState               │           │    
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐    │Middleware │   { $0.middlewareState }                      │           │    
        State            │   State   │◀──────────────────────────────────────────────│ AppState  │    
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘    │           │   KeyPath<AppState, MiddlewareState>          │           │    
                         └─────┬─────┘   \AppState.middlewareState                   │           │    
                                                                                     └───────────┘    
                               │                                                           │          
```

#### Optional transformation
If some action is running through the store, some reducers and middlewares may opt for ignoring it. For example, if the action tree has nothing to do with that middleware or reducer. That's why, every INCOMING action (Action for Middlewares and Reducers alike) is a transformation from `AppAction → Optional<Subset>`. Returning nil means that the action will be ignored.

This is not true for the other direction, when actions are dispatched by Middlewares, they MUST become an AppAction, we can't ignore what Middlewares have to say.

#### Direction of the arrows
**Reducers** receive actions (input action) and are able to read and write state.

**Middlewares/Behaviors** receive actions (input action), dispatch actions (output action) and only read the state (input state).

When lifting, we must keep that in mind because it defines the variance (covariant/contravariant) of the transformation, that is, _map_ or _contramap_.

One special case is the State for reducer, because that requires a read and write access, in other words, you are given an `inout Whole` and a new value for `Part`, you use that new value to set the correct path inside the inout Whole. This is precisely what WritableKeyPaths are meant for, which we will see with more details now.

#### Use of KeyPaths and Prisms
KeyPath is the same as `Global -> Part` transformation, where you give the description of the tree in the following way: `\Global.parent.part`.

WritableKeyPath has similar usage syntax, but it's much more powerful, allowing us to transform `(Global, Part) -> Global`, or `(inout Global, Part) -> Void` which is the same.

Prism is the sum-type equivalent: `Global -> Part?` for extraction and `Part -> Global` for construction. It's the right tool for enum cases.

That said we need to understand that KeyPaths are only possible when the direction of the arrows comes from `AppElement -> ReducerOrMiddlewareElement`, that is:
```
Reducer:
- ReducerAction? ← AppAction         // Prism is the right tool (enum case)
- ReducerState ←→ AppState           // WritableKeyPath is possible
```
```
Middleware/Behavior:
- MiddlewareInputAction? ← AppAction // Prism is the right tool (enum case)
- MiddlewareOutputAction → AppAction // Prism construction (not KeyPath)
- MiddlewareState ← AppState         // KeyPath is possible
```

For action lifting, Prism handles both the input filter and output wrap in one optic:
```swift
// AppAction.prism.counter is a Prism<AppAction, CounterAction>
counterBehavior.liftAction(AppAction.prism.counter)
```

For the `ReducerState ←→ AppState` and `MiddlewareState ← AppState` transformations, we use WritableKeyPath and KeyPath respectively. The whole tree must be composed by `var` properties, not `let`:
```swift
{ (globalState: AppState) -> PartState in
    globalState.something.thatsThePieceWeWant
}

{ (globalState: inout AppState, newValue: PartState) -> Void in
    globalState.something.thatsThePieceWeWant = newValue
}

// or
// WritableKeyPath<AppState, PartState>
\AppState.something.thatsThePieceWeWant // where:
                                        // var something
                                        // var thatsThePieceWeWant
```

For the `MiddlewareOutputAction → AppAction` we use a constructor function from the Prism, not a KeyPath:
```swift
{ (middlewareAction: MiddlewareAction) -> AppAction in 
    AppAction.treeForMiddlewareAction(middlewareAction)
}

// or simply
AppAction.treeForMiddlewareAction // a function reference, not a KeyPath
```

#### Identity, Ignore and Absurd
Void:
- when Middleware doesn't need State, it can be Void
- lift Void using `ignore`, which is `{ (_: Anything) -> Void in }`

Never:
- when Middleware doesn't need to dispatch actions, it can be Never
- lift Never using `absurd`, which is `{ (never: Never) -> Anything in }`

Identity:
- when some parts of your lift should be unchanged because they are already in the expected type
- lift that using `identity`, which is `{ $0 }`

Theory behind:
Void and Never are dual:
- Anything can become Void (terminal object)
- Never (initial object) can become Anything
- Void has 1 instance possible (it's a singleton)
- Never has 0 instances possible
- Because nobody can give you Never, you can promise Anything as a challenge. That's why function is called absurd, it's impossible to call it.

# Architecture

This dataflow is, somehow, an implementation of MVC, one that differs significantly from the Apple's MVC for offering a very strict and opinionated description of layers' responsibilities and by enforcing the growth of the Model layer, through a better definition of how it should be implemented: in this scenario, the Model is the Store. All your Controller has to do is to forward view actions to the Store and subscribe to state changes, updating the views whenever needed. If this flow doesn't sound like MVC, let's check a picture taken from Apple's website:

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
│┃░┃              └──────────┘            ┃░┃              │   StoreProjection       │             ┃                       ┃░
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

And what about SwiftUI? Is this architecture a good fit for the new UI framework? In fact, this architecture works even better in SwiftUI, because SwiftUI was inspired by several functional patterns and it's reactive and stateless by conception. In SwiftUI, the **View is a function of the state**, and we should always aim for single source of truth — data should always flow in a single direction.

# SwiftRex Architecture

`SwiftRex.Architecture` is an opinionated layer on top of `SwiftRex.SwiftUI` that co-locates every concern of a feature into a single `enum` namespace. You describe a feature once — its `State`, `Action`, `behavior()`, and a SwiftUI `Content` view — and the `@Feature` macro synthesizes the wiring (`initialState(with:)` and an erased `view(store:environment:) -> some View`), applies `@Lenses`/`@Prisms` for you, and builds the right kind of observable view store.

**Requires Swift 6.3+** (the `@Feature` macro does not compile under the Swift 6.2 toolchain). The macro itself is not availability-gated, so a `.combineObservable` feature builds down to the package floor (iOS 16, macOS 13, tvOS 16, watchOS 9; Linux/Windows/Android compile the whole SwiftUI/Observation layer out). The two Observation strategies gate the *generated* `view()` at iOS 17 / macOS 14 / tvOS 17 / watchOS 10.

## Core types

| Type | Role |
|---|---|
| `@Feature(type:strategy:)` | Macro on a feature `enum`. `type:` = `.moduleEntryPoint`/`.internalOnly`; `strategy:` = `.observationSimple`/`.observationGranular`/`.combineObservable`. Applies `@Prisms`/`@Lenses`, synthesizes `initialState(with:)` and an erased `view(store:environment:) -> some View`. |
| `@BoundTo(F.self, strategy:)` | Macro on a view struct. Injects a `viewStore` property with the wrapper matching the strategy (`let` for Observation, `@ObservedObject var` for Combine). |
| `@Tracked` | Macro on a `ViewState` struct. Generates an `@Observable` reference mirror for field-level view invalidation. |
| `ViewStore` / `TrackedViewStore` | `@Observable` view stores (coarse / field-level), both conforming to `StoreType`. |
| `ObservableObjectStore` | Combine `ObservableObject` view store (iOS 13+), for the `.combineObservable` strategy. |

## Anatomy of a feature

A `@Feature` enum has a few **required** nested members and several **optional** ones the macro synthesizes when omitted:

| Member | Required? | Omitted ⇒ |
|---|---|---|
| `struct State` | ✅ | — (gets `@Lenses`) |
| `enum Action` | ✅ | — (gets `@Prisms`) |
| `static func behavior() -> Behavior<Action, State, Environment>` | ✅ | — |
| `typealias Content = SomeView` | ✅ (to get a `view()`) | no `view()` is generated (logic-only feature) |
| `struct Environment` | optional | aliased to `Void` |
| `struct ViewState` | optional | aliased to `= State` |
| `enum ViewAction` | optional | aliased to `= Action` |
| `static let mapState` / `mapAction` | only when `ViewState`/`ViewAction` are declared | no projection — `view()` wraps the store directly |
| `typealias Input` | optional | `initialState(with:)` seeds from `State.init()` |

When you declare a distinct `ViewState`/`ViewAction`, you also write the two projection maps, each a `Reader` so they can format and parse with live dependencies:

```swift
static let mapState  = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { env in { state in … } }
static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action>        { env in { va    in … } }
```

The paired view struct is bound with `@BoundTo(Feature.self, strategy:)`, which injects the `viewStore`. The strategy is repeated there because a macro can't read another type's attributes; the compiler enforces the two agree, since the generated `view()` builds a store of exactly the injected type.

## The view body never changes

Whichever strategy you pick, the view reads state and sends actions the same way:

```swift
viewStore.state.<field>          // read
viewStore.dispatch(.<action>)    // send
```

`ViewStore` and `TrackedViewStore` both conform to `StoreType`, so the store-backed SwiftUI helpers work on the `viewStore` directly:

```swift
viewStore.binding(\.field, set: Action.someAction)       // two-way TextField/Toggle/…
viewStore.presence(\.optional, dismiss: .close)          // .sheet(isPresented:)
viewStore.item(\.selected, dismiss: .deselect)           // .sheet(item:)
```

## Field-level view invalidation

`.observationGranular` builds a `TrackedViewStore` and auto-applies `@Tracked` to the `ViewState`. `@Tracked` generates an `@Observable` reference mirror with one tracked property per field, updated in place. SwiftUI registers per-field dependencies during `body` evaluation, so only views that read a changed field re-render. `.observationSimple` (a coarse `ViewStore`) re-evaluates `body` on any state change instead — cheap, because SwiftUI's own structural diffing still skips redrawing subviews whose inputs didn't change. Reach for granular only on a genuinely hot, wide screen where you measured a win.

## The ladder — L0 → L4

Start at the leanest feature and add one concern at a time.

### L0 — the leanest feature

`State` + `Action` + `behavior()` + a `Content` view. No `Environment` (aliased to `Void`), no `ViewState`/`ViewAction` (aliased to `State`/`Action`) — the view reads the domain state directly.

```swift
@Feature(type: .internalOnly, strategy: .observationSimple)
enum Counter {
    struct State: Sendable, Equatable { var count = 0 }
    enum Action: Sendable { case tick }

    static func behavior() -> Behavior<Action, State, Environment> {
        .reduce { action, state in
            switch action {
            case .tick: state.count += 1
            }
        }
    }

    typealias Content = CounterView
}

@BoundTo(Counter.self, strategy: .observationSimple)
struct CounterView: View {
    // injected: let viewStore: ViewStore<Counter.State, Counter.Action>
    var body: some View {
        Button("count: \(viewStore.state.count)") { viewStore.dispatch(.tick) }
    }
}
```

### L1 — add dependencies

Declare an `Environment` and the effects can reach a client, a clock, or `now`. The behavior gains the third generic for free.

```swift
@Feature(type: .internalOnly, strategy: .observationSimple)
enum Log {
    struct State: Sendable, Equatable { var stamps: [Date] = [] }
    enum Action: Sendable { case mark; case marked(Date) }

    struct Environment: Sendable {
        var now: @Sendable () -> Date        // injected instead of an ambient Date()
    }

    static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, _ in
            switch action {
            case .mark:
                .produce { ctx in
                    Effect.task { .marked(ctx.environment.now()) }
                }
            case .marked(let date):
                .reduce { $0.stamps.append(date) }
            }
        }
    }

    typealias Content = LogView
}
```

### L2 — a distinct view shape

When the UI needs a different shape than the domain — an `Int` shown as a `String`, a joined list for a `TextField` — declare `ViewState`/`ViewAction` and the two maps. `mapAction` parses raw input back into a domain action.

```swift
@Feature(type: .internalOnly, strategy: .observationSimple)
enum HeroDetails {
    struct State: Sendable {
        var codename = "Kryptonian"
        var aliases  = ["Superman", "Man of Steel"]
        var powers   = ["flight", "heat vision"]
        var isRetired = false
    }

    enum Action: Sendable, Equatable {
        case savePowers([String])
        case toggleRetirement
    }

    struct Environment: Sendable {}

    struct ViewState: Sendable, Equatable {
        var displayName: String   // aliases.first ?? codename
        var powersText: String    // joined for the TextField
        var isRetired: Bool
    }

    enum ViewAction: Sendable {
        case editedPowers(String) // raw comma-separated TextField content
        case tappedRetirement
    }

    static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { _ in
        { s in
            .init(
                displayName: s.aliases.first ?? s.codename,
                powersText: s.powers.joined(separator: ", "),
                isRetired: s.isRetired
            )
        }
    }

    static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action> { _ in
        { va in
            switch va {
            case .editedPowers(let raw):
                .savePowers(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            case .tappedRetirement:
                .toggleRetirement
            }
        }
    }

    static func behavior() -> Behavior<Action, State, Environment> {
        .reduce { action, state in
            switch action {
            case .savePowers(let p):  state.powers = p
            case .toggleRetirement:   state.isRetired.toggle()
            }
        }
    }

    typealias Content = HeroDetailsView
}

@BoundTo(HeroDetails.self, strategy: .observationSimple)
struct HeroDetailsView: View {
    // injected: let viewStore: ViewStore<HeroDetails.ViewState, HeroDetails.ViewAction>
    var body: some View {
        Form {
            Text(viewStore.state.displayName).font(.headline)
            // `set:` is `(Value) -> ViewAction`, so pass the case constructor directly:
            TextField("Powers", text: viewStore.binding(\.powersText, set: HeroDetails.ViewAction.editedPowers))
            Toggle("Retired", isOn: viewStore.binding(\.isRetired, set: { _ in .tappedRetirement }))
        }
    }
}
```

### L3 — pick your observation

The strategy is the only thing that changes between these three — the view **body is identical**. Swap `.observationSimple` for `.observationGranular` (field-level; `@Tracked` is applied to `ViewState` for you) or `.combineObservable` (the pre-Observation Combine path, iOS 13+). `@BoundTo` mirrors the same strategy and injects the matching wrapper.

```swift
// Field-level — @Tracked auto-applied to ViewState, view holds a TrackedViewStore
@Feature(type: .internalOnly, strategy: .observationGranular)
enum Gadget {
    struct State: Sendable, Equatable { var name = "phone"; var battery = 100 }
    enum Action: Sendable { case rename(String) }
    struct ViewState: Sendable, Equatable { var title: String; var charge: Int } // no @Tracked here — added for you
    enum ViewAction: Sendable { case tapped }
    static let mapState  = Reader<Void, @MainActor @Sendable (State) -> ViewState> { _ in { .init(title: $0.name, charge: $0.battery) } }
    static let mapAction = Reader<Void, @Sendable (ViewAction) -> Action>          { _ in { _ in .rename("x") } }
    static func behavior() -> Behavior<Action, State, Environment> {
        .reduce { a, s in switch a { case .rename(let n): s.name = n } }
    }
    typealias Content = GadgetView
}

@BoundTo(Gadget.self, strategy: .observationGranular)
struct GadgetView: View {
    // injected: let viewStore: TrackedViewStore<Gadget.ViewState, Gadget.ViewAction>
    var body: some View { Text(viewStore.state.title) }   // invalidates only when `title` changes
}

// Combine — iOS 13+, view holds an @ObservedObject ObservableObjectStore; view() is generated ungated
@BoundTo(Widget.self, strategy: .combineObservable)
struct WidgetView: View {
    // injected: @ObservedObject var viewStore: ObservableObjectStore<Widget.ViewAction, Widget.ViewState>
    var body: some View { Text(viewStore.state.label) }
}
```

### L4 — a full module

A `.moduleEntryPoint` is a module's public entry: `State`/`Action`/`Environment`/`Input` are `public` (they must be liftable), and the generated `view(store:environment:)`/`initialState(with:)` are `public` too. It adds a seed (`Input`), an effect through the behavior, and state-driven navigation.

```swift
@Feature(type: .moduleEntryPoint, strategy: .observationSimple)
public enum Library {
    public struct Input: Sendable { public var shelfID: String }

    public struct State: Sendable, Equatable {
        var shelfID: String
        var isLoading = false
        var books: [Book] = []
        var selected: Book?        // non-nil ⇒ present the detail sheet
    }

    public enum Action: Sendable {
        case onAppear
        case loaded([Book])
        case tapped(Book)
        case dismissedDetail
    }

    public struct Environment: Sendable {
        public var fetch: @Sendable (String) async -> [Book]
    }

    // Seed the initial state from the Input handed in by the composing app.
    public static func initialState(with input: Input) -> State { .init(shelfID: input.shelfID) }

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, _ in
            switch action {
            case .onAppear:
                .reduce { $0.isLoading = true }
                .produce { ctx in
                    Effect.task {
                        let shelf = await ctx.liveState?.shelfID ?? ""
                        return .loaded(await ctx.environment.fetch(shelf))
                    }
                }
            case .loaded(let books):
                .reduce { $0.books = books; $0.isLoading = false }
            case .tapped(let book):
                .reduce { $0.selected = book }
            case .dismissedDetail:
                .reduce { $0.selected = nil }
            }
        }
    }

    typealias Content = LibraryView
}

@BoundTo(Library.self, strategy: .observationSimple)
struct LibraryView: View {
    // injected: let viewStore: ViewStore<Library.State, Library.Action>
    var body: some View {
        List(viewStore.state.books) { book in
            Button(book.title) { viewStore.dispatch(.tapped(book)) }
        }
        .onAppear { viewStore.dispatch(.onAppear) }
        // present-while-.some, dispatch .dismissedDetail when SwiftUI clears it:
        .sheet(item: viewStore.item(\.selected, dismiss: .dismissedDetail)) { book in
            Text(book.title)
        }
    }
}
```

The app composes the module into its parent store with the core `lift(...)`, projecting each axis. An optional child screen lifts through `liftOptional` (runs only while the sub-state is `.some`); a list of children lifts through `liftCollection`:

```swift
let appBehavior = Behavior.combine(
    Library.behavior().lift(
        action:      AppAction.prism.library,
        state:       \AppState.library,
        environment: { $0.library }
    ),
    HeroDetails.behavior().liftOptional(              // active only while heroDetail != nil
        action:      AppAction.prism.heroDetail,
        state:       \AppState.heroDetail,
        environment: { $0.heroDetail }
    )
)

let store = Store(initial: .init(), behavior: appBehavior, environment: appEnv)

// Render the module — the erased view() hides ViewState/ViewAction/Content behind `some View`:
Library.view(
    store: store.projection(action: AppAction.library, state: { $0.library }),
    environment: appEnv.library
)
```

## Layer isolation

| Layer | Knows | Never sees |
|---|---|---|
| `State`/`Action`/`Environment`/`Input` | the domain — lifted into the app | the view shape |
| `ViewState`/`ViewAction` + maps | the UI shape, the projection | the parent store types |
| `Content` view (`@BoundTo`) | `ViewState`/`ViewAction` via `viewStore` | all domain types |

On a `.moduleEntryPoint`, only `State`/`Action`/`Environment`/`Input` and the opaque `view()` cross the module boundary; the whole view layer stays `internal`.

## Navigation

Navigation is a **function of state** — one store, routes in state, native SwiftUI containers driven by store-backed bindings that *dispatch* on change. Every container maps to one of four shapes:

| Shape | State | Binding | Reducer | Containers |
|---|---|---|---|---|
| **Optional / modal** | `Item?` / `Bool` | `item(_:dismiss:)` / `presence(_:dismiss:)` | `navigationItem` | sheet, cover, popover, bottom sheet (detents), alert, confirmationDialog, inspector, `navigationDestination(isPresented:)` |
| **Stack** | `[Route]` | `path(_:set:)` | `navigationStack` | `NavigationStack(path:)` |
| **Selection** (1-of-N, all alive) | `Sel` | `selection(_:set:)` | `navigationSelection` | `TabView`, `.page`/carousel, `NavigationSplitView` |
| **Scene set** | keyed sub-states | `hasScene(_:in:)` + projection | open/close actions | `WindowGroup(for:)`, multi-window (one store) |

A **`Scope`** declares a child feature's wiring once and drives **both** its `behavior` and its `view` (`Scope(Detail.self, action: \.detail, state: \.detail, environment: \.detailEnv)`). A hand-written **router** (`@ViewBuilder view(for:)`, no `AnyView`) resolves a route to the child view, supplying the environment the env-free view body can't — the navigation crux. Effect lifecycle is state-driven: a supervisor reacting to route state cancels a screen's effects when it leaves. Full walkthrough: the **State-Driven Navigation** DocC article.

# Testing

The **`SwiftRex.Testing`** product ships `TestStore` — a deterministic, exhaustive harness for a feature's `behavior()`. Add it to your **test** target only, so production targets that depend on `SwiftRex` never link it:

```swift
.testTarget(
    name: "MyFeatureTests",
    dependencies: [
        "MyFeature",
        .product(name: "SwiftRex.Testing", package: "SwiftRex")
    ]
)
```

Because a feature's `Environment` is plain closures, tests just stub functions — no mocks, no protocols.

## `TestStore` — assert on domain `State`

`dispatch` runs the behavior synchronously and asserts the resulting `State`. Effects are captured in `pendingEffects` without firing; `runEffects()` drives them and collects their output into `receivedActions`, which `receive` then matches against a `Prism`. The assertion closure receives an `inout` copy of the state **before** the action — mutate it to describe the expected post-action state.

```swift
import SwiftRex
import SwiftRexTesting
import Testing

@MainActor
@Test func fetch_populatesBooks() async {
    let books = [Book(id: "1", title: "Dune")]

    let store = TestStore(
        initial: Library.initialState(with: .init(shelfID: "sci-fi")),
        behavior: Library.behavior(),
        environment: Library.Environment(fetch: { _ in books })
    )

    store.dispatch(.onAppear) { _ in }        // no state change; an effect is queued
    await store.runEffects()
    store.receive(Library.Action.prism.loaded) { loaded, state in
        state.books = loaded
    }
}
```

`dispatch` returns `self`, so pure (no-effect) chains read tersely:

```swift
store
    .dispatch(.tick) { $0.count = 1 }
    .dispatch(.tick) { $0.count = 2 }
```

`@Feature` applies `@Prisms` to your `Action` enum, so `Action.prism.caseName` is available for `receive` with no extra code. `TestStore` matches actions by `Prism`, so `Action` need not be `Equatable` — handy when a case carries a `Result` or a closure. By default `TestStore` is exhaustive: it fails if you `dispatch` with received actions still pending, or let the store deallocate with leftover effects, actions, or open channels. Pass `exhaustive: false` to relax all three. For a `Void`-environment feature there are `init(initial:behavior:)` and `init(initial:reducer:)` conveniences.

---

# Architecture & the Algebra

SwiftRex's core types form a small, lawful algebra. Composition is always the same idea — a **monoid** (`combine`, with an `identity`) — and there is exactly **one interpreter**, the `Store`. Everything else is a pure, composable value.

## The monoid lattice

Each type is a monoid; composing two values of a type gives a third of the same type, with an `identity` that does nothing:

| Type | `combine` semantics | `identity` |
|---|---|---|
| `Reducer<Action, State>` | **sequential** — run `lhs` then `rhs` on the same `inout State` (order matters; `rhs` sees `lhs`'s mutation) | no-op reducer |
| `Effect<Action>` | **parallel** — both subscribe closures run; the Store interprets them concurrently | `.empty` |
| `ReducerOutcome<State>` | absorb `.unchanged`; otherwise compose the `EndoMut` mutations | `.unchanged` |
| `Reaction<State, Env, Action>` | **product monoid** — componentwise: `ReducerOutcome` (sequential) × effect `Reader` (parallel) | `.doNothing` |
| `Supervision<Env, Action>` | the `Channel`s to `Keep` for a state; sets **union** | a reader to `[]` |
| `Behavior<Action, State, Env>` | the **free monoid** `[Consequence]` — concatenation (each consequence is a `reaction` or a `supervision`) | `.identity` (`[]`) |
| `Middleware<Action, State, Env>` | the effect-only `Behavior` (`produce` + `supervise`) | `.identity` |

A `Behavior` is `[Consequence]`. Its `handle` folds the action-clock `reaction`s into one `Reaction` — the pair of *what state change to apply* (`ReducerOutcome`) and *what effect to perform afterward* (`Reader<PostReducerContext, Effect>`). `Reaction` being a product monoid (and `Behavior` the free monoid over consequences) is what lets you compose whole features by composing their `Behavior`s: the state mutations fold sequentially, the effects merge in parallel, the supervisions union — all in one value. And each builder only *describes*; the `Store` is the boundary that **mutates** (`reduce`), **performs** (`produce`), and **keeps** (`supervise`).

## The Store is the only interpreter (an IO runtime)

`Reducer`, `Effect`, `Middleware`, and `Behavior` are inert descriptions — constructing them runs nothing. The `Store` is the sole place effects execute and state mutates. It dispatches each action, on `@MainActor`, in phases:

1. **Phase 1 — pre-mutation.** `behavior.handle(action, preReducerContext)` folds the action-clock reactions into one `Reaction`. The context exposes the *pre-mutation* state.
2. **Phase 2 — mutation (zero-copy).** If the outcome is `.unchanged`, nothing happens — **no observer is notified**. Otherwise: `willChange` → the `EndoMut` mutates `state` in place (no copy) → `didChange`.
3. **Phase 3 — effects.** A `PostReducerContext` (now exposing *post-mutation* state and the `Environment`) resolves the effect `Reader`; each resulting component is scheduled per its `EffectScheduling` (`.immediately`, `.replacing(id:)`, `.debounce(id:delay:)`, `.throttle(id:interval:)`, `.cancelInFlight(id:)`). Actions produced by effects loop back to Phase 1.

This yields the framework's guarantees:

- **One notification per state-changing action.** A composed `Behavior` runs *all* its units inside a single `handle` call; by Swift's Law of Exclusivity the Store regains `state` only after the whole pipeline finishes — observers never see a half-applied state. Actions that can't change state (`.unchanged`) notify **zero** times.
- **Zero-copy mutation.** State is mutated through `inout` / `EndoMut`, never copied to diff.
- **Effects see committed state.** Effect closures resolve against post-mutation state.
- **Re-entrancy is safe.** Actions dispatched while the Store is mid-drain are queued and processed FIFO; a runaway loop is cut off at `StoreHooks.reentranceThreshold`.

`Store` is a `final class` with a fully `@MainActor` surface (so `withAnimation { store.dispatch(...) }` just works). Two pure boundary helpers narrow it for views: **`StoreProjection`** is a *stateless* `struct` that maps global action/state to a local slice (a lens with no storage of its own), and **`StoreBuffer`** is the caching/deduplicating layer (skips propagation when the projected slice is unchanged, via `Equatable` or a custom predicate).

> The upcoming state-driven-effects redesign adds a fourth entity (`Subscription`) and decomposes the effect engine; this section is updated in the same PR when that lands.

---

# Installation

## Swift Package Manager

SwiftRex is distributed exclusively via Swift Package Manager. Add it to your `Package.swift`:

```swift
// swift-tools-version:6.3   // @Feature macro requires Swift 6.3+

import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .executable(name: "MyApp", targets: ["MyApp"])
    ],
    dependencies: [
        // Enable the trait(s) for the third-party bridge(s) you want. Omit `traits:`
        // entirely if you only use the core, Combine, or SwiftConcurrency products —
        // then RxSwift/ReactiveSwift/ReactiveConcurrency are never even downloaded.
        .package(
            url: "https://github.com/SwiftRex/SwiftRex.git",
            from: "1.0.0",
            traits: ["RxSwift"]   // e.g. ["RxSwift", "ReactiveConcurrency"]
        )
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: [
                // Pick one or more (a gated bridge also needs its trait above):
                .product(name: "SwiftRex", package: "SwiftRex"),                    // Core only — no trait
                .product(name: "SwiftRex.SwiftConcurrency", package: "SwiftRex"),   // async/await — no trait
                .product(name: "SwiftRex.Combine", package: "SwiftRex"),            // Combine — no trait
                .product(name: "SwiftRex.RxSwift", package: "SwiftRex"),            // needs trait "RxSwift"
                // .product(name: "SwiftRex.ReactiveSwift", package: "SwiftRex"),        // needs trait "ReactiveSwift"
                // .product(name: "SwiftRex.ReactiveConcurrency", package: "SwiftRex"),  // needs trait "ReactiveConcurrency"
            ]
        ),
        .testTarget(
            name: "MyAppTests",
            dependencies: [
                "MyApp",
                .product(name: "SwiftRex.Testing", package: "SwiftRex"),            // TestStore
            ]
        )
    ]
)
```

Supported platforms: macOS 13+, iOS 16+, tvOS 16+, watchOS 9+, visionOS 1+, Linux (Swift 6.3+).

`SwiftRex`, `SwiftRex.SwiftConcurrency`, and `SwiftRex.Testing` are fully cross-platform including Linux. `SwiftRex.Combine` and `SwiftRex.SwiftUI` require Apple platforms. `SwiftRex.RxSwift`, `SwiftRex.ReactiveSwift`, and `SwiftRex.ReactiveConcurrency` require their respective traits enabled (above), and the first two require Apple platforms unless those frameworks add Linux support.

You can also add SwiftRex directly in Xcode via **File > Add Package Dependencies** and entering the repository URL `https://github.com/SwiftRex/SwiftRex.git`.

## XCFrameworks

Pre-built XCFrameworks for the dependency-free products are attached to each [GitHub release](https://github.com/SwiftRex/SwiftRex/releases):

| Framework | Contents |
|---|---|
| `SwiftRex.xcframework.zip` | Core store, reducers, behaviors, effects |
| `SwiftRex.Operators.xcframework.zip` | Symbolic operators (`<>`, `\|>`, `>>>`, …) |
| `SwiftRex.SwiftConcurrency.xcframework.zip` | async/await Effect bridges |
| `SwiftRex.Combine.xcframework.zip` | Combine publisher bridge |
| `SwiftRex.SwiftUI.xcframework.zip` | SwiftUI integration (`ViewStore`, `TrackedViewStore`, `ObservableObjectStore`, `asObservableObject`) |

The third-party reactive bridges (`SwiftRex.RxSwift`, `SwiftRex.ReactiveSwift`, `SwiftRex.ReactiveConcurrency`) are trait-gated and depend on third-party frameworks; use SPM for those products.

To integrate an XCFramework manually: download the `.zip` from the release, unzip it, and drag the `.xcframework` bundle into your Xcode project's **Frameworks, Libraries, and Embedded Content** section.
