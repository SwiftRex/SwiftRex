# Action

An Action represents an event that was notified by external (or sometimes internal) actors of your app. It's about relevant INPUT events.

## Overview

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
