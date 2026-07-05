# State-Driven Navigation

Model navigation as a function of state: routes live in state, SwiftUI bindings dispatch, and a router builds destination views — resolving the environment that an env-free view body can't.

## Overview

Navigation in SwiftRex is **pure SwiftUI Views reacting to state**. There is one store for the whole app; a view holds only a projection. Behavior mutates the navigation *state* (a route, an optional, a path, a selection); it never touches the view or the router. Standard SwiftUI containers (`sheet`, `NavigationStack`, `TabView`, windows) are pluggable renderings of a few state *shapes*.

Four shapes cover it:

| Shape | State | Lift | SwiftUI binding | Container |
| --- | --- | --- | --- | --- |
| Optional / modal | `Item?` (or `Bool`) | `liftOptional` | `item(_:dismiss:)` / `presence(_:dismiss:)` | sheet, cover, popover |
| Stack | `[Route]` | `liftCollection` | `path(_:set:)` | `NavigationStack(path:)` |
| Selection (1-of-N) | `Sel` | plain `lift` ×N | `selection(_:set:)` | `TabView`, split view |
| Scene set | keyed sub-states | element projection | `WindowGroup(for:)` | windows |

## Scope — declare the wiring once

A ``Scope`` captures how a child feature embeds into the app store — action prism, state key path, environment narrowing — and derives its `lifted` behavior. Constructing one is a **compile-time proof** the feature is wired; a missing state slot, action case, or env mapping is a compile error at the literal.

```swift
let detailScope = Scope(
    behavior:    Detail.behavior(),
    action:      \.detail,      // PrismKeyPath<AppAction, Detail.Action>
    state:       \.detail,      // WritableKeyPath<AppState, Detail.State>
    environment: \.detailEnv    // KeyPath<World, Detail.Environment>
)
```

Register every scope in one place with ``Scopes`` so you can't forget to compose a behavior:

```swift
let features = Scopes(homeScope, detailScope, settingsScope)
let appBehavior = Behavior.combine([features.behavior, navigationReducer])
let store = Store(initial: .init(), behavior: appBehavior, environment: world)
```

## Bindings — the WHEN

Store-backed bindings drive native SwiftUI containers; a write dispatches an action, so presentation stays a function of state.

```swift
.sheet(item: store.item(\.selected, dismiss: .deselect)) { item in … }
NavigationStack(path: store.path(\.path, set: NavAction.setPath)) { root }
TabView(selection: store.selection(\.tab, set: AppAction.selectTab)) { … }
```

## Navigation reducers — apply, or veto

Fold a navigation reducer into the app behavior to handle the standard operations. Default applies every op; pass `allow` to veto or gate one (return `false` to block) — a vetoed op leaves state unchanged and the binding re-presents.

```swift
Behavior.navigationStack(\.path, action: \.nav)                         // push/pop/setPath
Behavior.navigationItem(\.sheet, action: \.modal) { op, s in !s.isDirty } // block dismiss while dirty
Behavior.navigationSelection(\.tab, action: \.select)
```

## Router — the WHAT (and the environment crux)

`Feature.view(store:environment:)` needs an environment, but a navigation destination runs inside the *environment-free* view body. A **router** — a value holding the store and the world — resolves that: its `@ViewBuilder view(for:)` switch builds each child, supplying the child's environment there. `some View` throughout — no `AnyView`.

```swift
@MainActor struct AppRouter {
    let store: MainStore
    let world: World

    @ViewBuilder func view(for route: AppRoute) -> some View {
        switch route {
        case .detail:
            Detail.view(
                store: store.projection(action: \.detail, state: \.detail),
                environment: world.detailEnv                 // env supplied here
            )
        }
    }
}
```

A navigating view conforms to ``Routable`` and holds its router as a `let`, handed in at construction. Because the router builds every view, it re-hands itself at each construction — deterministic across the sheet/modal boundaries where SwiftUI's `@Environment` propagation is unreliable. The view's body stays environment-free:

```swift
struct HomeView: View, Routable {
    let viewStore: ViewStore<Home.State, Home.Action>
    let router: AppRouter                                     // trapped at construction

    var body: some View {
        List { … }
            .sheet(isPresented: viewStore.presence(\.route, dismiss: .dismiss)) {
                router.view(for: .detail)                     // router supplies env — crux resolved
            }
    }
}
```

The view never names `Detail` — the router does. A route may resolve to a completely separate module (its own store slice / dependencies) without the presenting feature importing it.

## Multi-scene is single-store

Multiple windows are still one store. Model open scenes as state (a dictionary of per-scene sub-states); each window projects its slice by id; open/close are ordinary actions.

```swift
var body: some Scene {
    WindowGroup { RootView(store: store, router: router) }
    WindowGroup(for: DocID.self) { $id in
        if let id, store.hasScene(id, in: \.documents) {
            Document.view(store: store.projection(key: id, actionReview: AppAction.document, stateDictionary: \.documents), environment: world.docEnv)
        }
    }
}
```

## Topics

- ``Scope``
- ``Scopes``
- ``Routable``
