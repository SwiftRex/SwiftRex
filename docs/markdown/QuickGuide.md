# Quick Guide

This is a TL;DR in case you want to start quickly, without too much theory, or in case you're already pretty familiar with other redux implementations. We still recommend the other topics for a deeper understanding behind SwiftRex concepts.

The minimum implementation is:
- an `AppAction` (enum)
- an `AppState` (struct)
- a `Store` (class)
- an app `Reducer<AppAction, AppState>` (function) 
- an app `Middleware` (class).

---

## Very minimum Counter Example

Let's start with a counter that has no side-effects, therefore we're going to use `IdentityMiddleware()` that simply ignores all events.

```swift
struct AppState {
    var count: Int
}

enum AppAction {
    case increment
    case decrement
}
```

Users can dispatch increment and decrement actions. These are expected to, evidently, increment or decrement the count in the AppState.

Entity responsible for mutating the state is the Reducer, let's create one:

```swift
let counterReducer = Reducer<AppAction, AppState> { action, state in
    switch action {
    case .decrement:
        return AppState(count: state.count - 1)
    case .increment:
        return AppState(count: state.count + 1)
    }
}
```

This is basically a function wrapped in a struct, and this function receives an action and an state, and is expected to calculate a new state depending on the action. An app is expected to have multiple reducers, each of them specialized in a narrow area, so composing multiple reducers is possible using `<>` operator, as long as they "speak the same" generics. If they don't, it's also easy to solve and we're going to see later in this quick guide. For now, let's compose all the reducers we have in a single appReducer:

```swift
let appReducer = counterReducer // <> anotherReducer <> andYetAnotherReducer
```

Only one, for now.

As said before, we won't have Middlewares in this example because we are not having any side-effects, so that's all we need to create a store. This time we're gonna use Combine, but this will be similar for any other Reactive Framework.

```swift
let store = ReduxStoreBase<AppAction, AppState>(
    subject: .combine(initialValue: AppState(count: 0)),
    reducer: appReducer,
    middleware: IdentityMiddleware() // <- No side-effects yet
)
```

We are ready to use it.

```swift
let cancellable = store.statePublisher.sink {
    print("Got new state: \($0)")
}

store.dispatch(.increment)
store.dispatch(.increment)
store.dispatch(.decrement)
store.dispatch(.increment)
store.dispatch(.decrement)
store.dispatch(.decrement)
store.dispatch(.decrement)
store.dispatch(.increment)
```

---

## Lifting Reducer

However all reducers could work on the whole AppAction, AppState all the time, it's better to limit their scope to avoid bugs and switch/cases with `default` pattern match. Let's review our example above, but now we're going to have a CountAction which is only one possible case in a much broader AppAction.

```swift
struct AppState {
    var count: Int
}

enum AppAction {
    case count(CountAction)
    // case another action category
    // case and another action category
}

enum CountAction {
    case increment
    case decrement
}
```

First of all, our Reducer doesn't need to see the whole AppAction if it only handles CountAction, so our reducer will only see that.
The whole AppState also seems to be too much for it, it only cares about a single property, the `count: Int`. So we can limit its state to the very bare minimum `Int` which is expected to be the count.

```swift
let counterReducer = Reducer<CountAction, Int> { action, state in
    switch action {
    case .decrement:
        return state - 1
    case .increment:
        return state + 1
    }
}
```

The generic parameters explain exactly what's happening there and the input types: `state` is a mere `Int`, so we can perform Math directly on it, and return a mere `Int`.

However, we can't plug this reducer any more as it's working on different types than our store. We want to "lift" this reducer to the store types.

Let's start with the full syntax to make clear.

```swift
let appReducer = counterReducer.lift(
    actionGetter: { (appAction: AppAction) -> CountAction? in 
        guard case let AppAction.count(countAction) = appAction else { return nil }
        return countAction
    },
    stateGetter: { (appState: AppState) -> Int in 
        appState.count 
    },
    stateSetter: { (appState: inout AppState, newCount: Int) in
        appState.count = newCount
    }
) // <> anotherReducer.lift(...) <> .identity
```

Ok, there's a lot happening in here, but it's important to show the expanded version of lift before swimming in the sugar pool, so please bear 🐻 with me.

When we lift a reducer, we need to tell the new lifted reducer how to translate local types into global types and vice-versa. Reducers are able to:
- receive actions (incoming)
- receive state (incoming)
- return state (outgoing)

That's why we need to provide these 3 closures. More details about that are shown in the [README Lifting Reducer Chapter](../../README.md#lifting-reducer). However, we can use a simplified lift syntax as long as our [AppAction has enum case properties](ActionEnumProperties.md).

```swift
let appReducer = counterReducer.lift(
    action: \AppAction.count,
    state: \AppState.count
) // <> anotherReducer.lift(...) <> .identity
```

Much better, right? And because `count` is a `var` in the `AppState`, the second parameter is a `WritableKeyPath` so we don't need to teach the state getter and setter as two different parameters.

Good lifting can be challenging for those not confident with Swift generics or KeyPaths. If this is your case, download the Xcode Code Snippet for the full expanded reducer lift in [here](CodeSnippet/LiftReducerExpanded.codesnippet), otherwise maybe the compact reducer lift can be found in [here](CodeSnippet/LiftReducerCompact.codesnippet). The compact version also depends on [AppAction has enum case properties](ActionEnumProperties.md).

We can now create our Store, observe it and dispatch actions to it.

```swift
let store = ReduxStoreBase<AppAction, AppState>(
    subject: .combine(initialValue: AppState(count: 0)),
    reducer: appReducer,
    middleware: IdentityMiddleware() // <- No side-effects yet
)

let cancellable = store.statePublisher.sink {
    print("Got new state: \($0)")
}

store.dispatch(.count(.increment))
store.dispatch(.count(.increment))
store.dispatch(.count(.decrement))
store.dispatch(.count(.increment))
store.dispatch(.count(.decrement))
store.dispatch(.count(.decrement))
store.dispatch(.count(.decrement))
store.dispatch(.count(.increment))
```

---

## Store Projection and View Models

On the previous chapter we've learned how to make the scope of reducers more narrow, so they can't mess with things they don't understand. That not only prevents bugs but also unlocks modularization, so reducers can be in different frameworks and lifted to the global types only in the main target.

Why not doing the same with Views? If Views could always talk to the full Store they:
- would read much more state than they will ever need
- would get refreshed when parts of the state they don't even care about are changed
- could dispatch actions for paths they were not supposed to

The second issue is specially important to avoid, you don't want your UI reloading for nothing.

```swift
struct CounterViewState: Equatable {
    let formattedCount: String

    static func from(appState: AppState) -> CounterViewState {
        .init(formattedCount: "\(appState.count)")
    }
}

 // View action (everything the user inputs to the app)
enum CounterViewAction {
    case tapPlus
    case tapMinus

    var asAppAction: AppAction? {
        switch self {
        case .tapPlus: return .count(.increment)
        case .tapMinus: return .count(.decrement)
        }
    }
}
```

We start creating a completely isolated pair of State and Action only for our View. Although this is not required, it's how usually MVVM architectures approach backend/frontend separation and could be helpful to establish a transformation layer where number/date formatting, string localization and other UI work are done. This is completely optional, but recommended. The two functions that bridge UI types to Store types are created in the ViewState and ViewAction entities, but they could also be in a Presenter or ViewModel class if this is your way to go.

```swift
let viewModel: StoreProjection<CounterViewAction, CounterViewState> =
    store.projection(
        action: \CounterViewAction.asAppAction,
        state: CounterViewState.from(appState:)
    )
```

Our viewModel acts as a Store, but it's only a projection of a Store, implementing the very same `StoreType` protocol so it works as a regular Store. But every Action or State will be transformed by that pair of functions we specified. Now, our View is completely limited to `CounterViewState` and `CounterViewAction`, and the semantic of `CounterViewAction` resemble button events instead of business logic. The same way, `CounterViewState` has formatted properties ready to be shown in a Label or SwiftUI Text without any view logic.

```swift
let cancellable = viewModel.statePublisher.sink {
    print("Got new state: \($0)")
}

viewModel.dispatch(.tapPlus)
viewModel.dispatch(.tapPlus)
viewModel.dispatch(.tapMinus)
viewModel.dispatch(.tapPlus)
viewModel.dispatch(.tapMinus)
viewModel.dispatch(.tapMinus)
viewModel.dispatch(.tapMinus)
viewModel.dispatch(.tapPlus)
```

---

## Side Effects

So far we haven't seen any side-effect. Now, let's create a middleware that monitors shake gestures and increment the counter every time the user shakes the iPhone.

First of all, let's create an Action to start or stop the shake gesture.

```swift
enum AppAction {
    case count(CountAction)
    case shake(ShakeAction)
}

enum CountAction {
    case increment
    case decrement
}

enum ShakeAction {
    case start
    case shaken
    case stop
}
```

We're going to use Combine but in this case a pure NotificationCenter observation would be enough.

```swift

import Combine
import Foundation
import SwiftRex

class ShakeMiddleware: Middleware {
    // start of boilerplate
    // there are other higher level middlewares implementations
    // that hide most of this code, we're showing the complete
    // stuff to go very basic
    init() { }

    private var getState: GetState<AppState>!
    private var output: AnyActionHandler<AppAction>!
    func receiveContext(getState: @escaping GetState<AppState>, output: AnyActionHandler<AppAction>) {
        self.getState = getState
        self.output = output
    }
    // end of boilerplate

    // Side-effect subscription
    private var shakeGesture: AnyCancellable?

    func handle(action: AppAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        // an action arrived, do we care about it?
        switch action {
        case .shake(.start):
            // let's start the side-effect observation
            shakeGesture = NotificationCenter.default.publisher(for: Notification.Name.ShakeGesture).sink { [weak self] _ in
                // every time we detect a device shake, we dispatch a .shake(.shaken) action in response
                self?.output.dispatch(.shake(.shaken))
            }

        case .shake(.stop):
            // effect cancellation, user doesn't want this any more, Combine AnyCancellable will stop that for us
            shakeGesture = nil

        case .shake(.shaken):
            // .shake(.shaken) is an action that we dispatched ourselves, and we're receiving it back
            // although this extra roundtrip is optional, it helps to "tell a story" in your logs.
            output.dispatch(.count(.increment))

        case .count:
            // we don't care about incoming count actions
            break
        }
    }
}

// Extra stuff for this gesture
extension Notification.Name {
    public static let ShakeGesture = Notification.Name.init("ShakeGesture")
}
// For SwiftUI this is the way to go, for UIKit you can do the same in your main UIViewController
class HostingController<ContentView: View>: UIHostingController<ContentView> {
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        NotificationCenter.default.post(name: NSNotification.Name.ShakeGesture, object: nil)
    }
}
```

Let's use it.

```swift
let appMiddleware = ShakeMiddleware() // <> AnotherMiddleware() <> AndAnother()

let store = ReduxStoreBase<AppAction, AppState>(
    subject: .combine(initialValue: AppState(count: 0)),
    reducer: appReducer,
    middleware: appMiddleware
)

let cancellable = store.statePublisher.sink {
    print("Got new state: \($0)")
}

store.dispatch(.shake(.start))
```

We can start the side-effect (`store.dispatch(.shake(.start))`) in response to `.appInForeground` action, and stop it (`store.dispatch(.shake(.stop))`) in response to a `.appInBackground` action. Because a middleware can dispatch functions to itself, we can use that to "tell a store". Instead of simply dispatching `.count(.increment)` directly from the shake gesture closure, we decided to dispatch first a `.shake(.shaken)` and, later, in response to `.shake(.shaken)` we finally dispatch `.count(.increment)`.

This is not required, but helps to understand where the increment came from, not from the user, but from a shake gesture. This also helps to debug possible problems with your side-effect frameworks.

You can always choose a more direct approach, and that's perfectly fine!

---

## SwiftUI

SwiftRex works for UIKit, AppKit, WatchKit, SwiftUI and probably any other presentation framework, on Mac, Linux or mobile devices.
But because we are excited about SwiftUI functional programming style, let's implement a whole app with all features seen in this Quick Guide and some new ones, as lifting Middlewares.

```swift
import Combine
import CombineRex
import SwiftRex
import SwiftUI
import UIKit

// - MARK: - Xcode Minimum Template
@UIApplicationMain class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        true
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let contentView = ContentView(viewModel: CounterViewModel.viewModel(from: store))
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = HostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }
}

// MARK: - Functional helpers
func ignore<T>(_ t: T) -> Void { }
func identity<T>(_ t: T) -> T { t }
func absurd<T>(_ never: Never) -> T { }

// MARK: - Action / State
struct AppState {
    var count: Int
}
enum AppAction {
    case count(CountAction)
    case shake(ShakeAction)
}
enum CountAction {
    case increment
    case decrement
}
enum ShakeAction {
    case start
    case shaken
    case stop
}

// MARK: - Reducer
let counterReducer = Reducer<CountAction, Int> { action, state in
    switch action {
    case .decrement:
        return state - 1
    case .increment:
        return state + 1
    }
}
let appReducer = counterReducer.lift(
    action: \AppAction.count,
    state: \AppState.count
)

// MARK: - Middleware
class ShakeMiddleware: Middleware {
    private var shakeGesture: AnyCancellable?
    private var getState: GetState<Void>!
    private var output: AnyActionHandler<AppAction>!
    func receiveContext(getState: @escaping GetState<Void>, output: AnyActionHandler<AppAction>) {
        self.getState = getState
        self.output = output
    }

    func handle(action: ShakeAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        switch action {
        case .start:
            shakeGesture = NotificationCenter.default.publisher(for: Notification.Name.ShakeGesture).sink { [weak self] _ in
                self?.output.dispatch(.shake(.shaken))
            }

        case .stop:
            shakeGesture = nil

        case .shaken:
            output.dispatch(.count(.increment))
        }
    }
}
extension Notification.Name {
    public static let ShakeGesture = Notification.Name.init("ShakeGesture")
}
class HostingController<ContentView: View>: UIHostingController<ContentView> {
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        NotificationCenter.default.post(name: NSNotification.Name.ShakeGesture, object: nil)
    }
}

let appMiddleware: AnyMiddleware<AppAction, AppAction, AppState> = ShakeMiddleware().lift(
    inputActionMap: \AppAction.shake,
    outputActionMap: identity,
    stateMap: ignore
).eraseToAnyMiddleware()

// MARK: - Action Enum Properties (use Sourcery for boilerplate code generation)
extension AppAction {
    public var count: CountAction? {
        guard case let .count(value) = self else { return nil }
        return value
    }
    public var shake: ShakeAction? {
        guard case let .shake(value) = self else { return nil }
        return value
    }
}

// MARK: - Store
let store = ReduxStoreBase<AppAction, AppState>(
    subject: .combine(initialValue: AppState(count: 0)),
    reducer: appReducer,
    middleware: appMiddleware
)

// MARK: - ViewModel
enum CounterViewModel {
    static func viewModel<S: StoreType>(from store: S) -> ObservableViewModel<ViewAction, ViewState> where S.ActionType == AppAction, S.StateType == AppState {
        store.projection(
            action: transform(viewAction:),
            state: transform(appState:)
        ).asObservableViewModel(initialState: .empty)
    }

    struct ViewState: Equatable {
        let title: String = "Welcome to the Redux counter"
        let formattedCount: String
        static var empty: ViewState {
            .init(formattedCount: "")
        }
    }

    enum ViewAction {
        case tapPlus
        case tapMinus
        case onAppear
        case onDisappear
    }

    private static func transform(viewAction: ViewAction) -> AppAction? {
        switch viewAction {
        case .tapPlus: return .count(.increment)
        case .tapMinus: return .count(.decrement)
        case .onAppear: return .shake(.start)
        case .onDisappear: return .shake(.stop)
        }
    }

    private static func transform(appState: AppState) -> ViewState {
        ViewState(formattedCount: "\(appState.count)")
    }
}

// MARK: - View
struct ContentView: View {
    @ObservedObject var viewModel: ObservableViewModel<CounterViewModel.ViewAction, CounterViewModel.ViewState>

    var body: some View {
        VStack {
            Spacer()
            Text(viewModel.state.title)
            Spacer()
            HStack {
                Spacer()
                Button("-") { self.viewModel.dispatch(.tapMinus) }
                Spacer()
                Text(viewModel.state.formattedCount)
                Spacer()
                Button("+") { self.viewModel.dispatch(.tapPlus) }
                Spacer()
            }
            Spacer()
        }
        .padding()
        .onAppear { self.viewModel.dispatch(.onAppear) }
        .onDisappear { self.viewModel.dispatch(.onDisappear) }
    }
}
```