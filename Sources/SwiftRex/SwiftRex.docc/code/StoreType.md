# ``SwiftRex/StoreType``

Store Type is an ``ActionHandler``, which means actors can dispatch actions (``ActionHandler/dispatch(_:)``) that will be handled by this store. These
actions will eventually start side-effects or change state. These actions can also be dispatched by the result of side-effects, like the callback of
an API call, or CLLocation new coordinates. How this action is handled will depend on the different implementations of ``StoreType``.

Store Type is also a ``StateProvider``, which means it's aware of certain state and can notify possible subscribers about changes through its 
publisher (``StateProvider/statePublisher``). If this ``StoreType`` owns the state (single source-of-truth) or only proxies it from another store will
depend on the different implementations of the protocol.

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

There are implementations that will be the actual Store, the one and only instance that will be the central hub for the whole redux architecture.
Other implementations can be only projections or the main Store, so they act like a Store by implementing the same roles, but instead of owning the
global state or handling the actions directly, these projections only apply some small (and pure) transformation in the chain and delegate to the real
Store. This is useful when you want to have local "stores" in your views, but you don't want them to duplicate data or own any kind of state, but only
act as a store while using the central one behind the scenes.

For more information about real stores, please check ``ReduxStoreBase`` and ``ReduxStoreProtocol``, and for more information about the projections
please check ``StoreProjection`` and ``StoreType/projection(action:state:)``.

## What is a Real Store?

A real Store is a class that you want to create and keep alive during the whole execution of an app, because its only responsibility is to act as a 
coordinator for the Unidirectional Dataflow lifecycle. That's also why we want one and only one instance of a Store, so either you create a static
instance singleton, or keep it in your AppDelegate. Be careful with SceneDelegate if your app supports multiple windows and you want to share the 
state between these multiple instances of your app, which you usually want. That's why AppDelegate, singleton or global variable is usually 
recommended for the Store, not SceneDelegate. In case of SwiftUI you can create a store in your app protocol as a ``Combine/StateObject``:
```swift
@main
struct MyApp: App {
    @StateObject var store = Store.createStore(dependencyInjection: World.default).asObservableViewModel(initialState: .initial)

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: ContentViewModel(store: store))
        }
    }
}
```
SwiftRex will provide a protocol (``ReduxStoreProtocol``) and a base class (``ReduxStoreBase``) for helping you to create your own Store.

```swift
class Store: ReduxStoreBase<AppAction, AppState> {
    static func createStore(dependencyInjection: World) -> Store {
        let store = Store(
            subject: .combine(initialValue: .initial),
            reducer: AppModule.appReducer,
            middleware: AppModule.appMiddleware(dependencyInjection: dependencyInjection)
            emitsValue: .whenDifferent
        )

        store.dispatch(AppAction.lifecycle(LifeCycleAction.start))
        return store
    }
}
```

## What is a Store Projection?

Very often you don't want your view to be able to access the whole App State or dispatch any possible global App Action. Not only it could refresh
your UI more often than needed, it also makes more error prone, put more complex code in the view layer and finally decreases modularisation making
the view coupled to the global models.

However, you don't want to split your state in multiple parts because having it in a central and unique point ensures consistency. Also, you don't
want multiple separate places taking care of actions because that could potentially create race conditions. The real Store is the only place actually
owning the global state and effectively handling the actions, and that's how it's supposed to be.

To solve both problems, we offer a ``StoreProjection``, which conforms to the ``StoreType`` protocol so for all purposes it behaves like a real store,
but in fact it only projects the real store using custom types for state and actions, that is, either a subset of your models (a branch in the state
tree, for example), or a completely different entity like a View State. A ``StoreProjection`` has 2 closures, that allow it to transform actions and
state between the global ones and the ones used by the view. That way, the View is not coupled to the whole global models, but only to tiny parts of
it, and the closure in the ``StoreProjection`` will take care of extracting/mapping the interesting part for the view. This also improves performance,
because the view will not refresh for any property in the global state, only for the relevant ones. On the other direction, view can only dispatch a
limited set of actions, that will be mapped into global actions by the closure in the ``StoreProjection``.

A Store Projection can be created from any other ``StoreType``, even from another ``StoreProjection``. It's as simple as calling 
``StoreType/projection(action:state:)``, and providing the action and state mapping closures:

```swift
let storeProjection = store.projection(
    action: { viewAction in viewAction.toAppAction() } ,
    state: { globalState in MyViewState.from(globalState: globalState) }
).asObservableViewModel(initialState: .empty)
```

## All together

Putting everything together we could have:

```swift
@main
struct MyApp: App {
    @StateObject var store = Store.createStore(dependencyInjection: World.default).asObservableViewModel(initialState: .initial)

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: store.projection(
                    action: { (viewAction: ContentViewAction) -> AppAction? in
                        viewAction.toAppAction()
                    },
                    state: { (globalState: AppState) -> ContentViewState in 
                        ContentViewState.from(globalState: globalState) 
                    }
                ).asObservableViewModel(initialState: .empty)
            )
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
        case .onAppear: return AppAction.foo(.bar(.startTimer))
        }
    }
}
```

In this example above we can see that `ContentView` doesn't know about the global models, it's limited to `ContentViewAction` and `ContentViewState`
only. It also only refreshes when `globalState.foo.bar.title` changes, any other change in the `AppState` will be ignored because the other properties
are not mapped into anything in the `ContentViewState`. Also, `ContentViewAction` has a single case, `onAppear`, and that's the only thing the view
can dispatch, without knowing that this will eventually start a timer (`AppAction.foo(.bar(.startTimer))`). The view should not know about domain
logic and its actions should be limited to `buttonTapped`, `onAppear`, `didScroll`, `toggle(enabled: Bool)` and other names that only suggest UI
interaction. How this is mapped into App Actions is responsibility of other parts, in our example, `ContentViewAction` itself, but it could be a
Presenter layer, a View Model layer, or whatever structure you decide to create to organise your code.

Testing is also made easier with this approach, as the View doesn't hold any logic and the projection transformations are pure functions.

![Store, StoreProjection and View](StoreProjectionDiagram)
