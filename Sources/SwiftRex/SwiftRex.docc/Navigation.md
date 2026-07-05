# State-Driven Navigation

Model navigation as a function of state: routes live in state, SwiftUI bindings dispatch, and a router builds destination views — resolving the environment that an env-free view body can't.

## Overview

Navigation in SwiftRex is **pure SwiftUI Views reacting to state**. There is one store for the whole app; a view holds only a projection. Behavior mutates the navigation *state* (a route, an optional, a path, a selection); it never touches the view or the router. Every SwiftUI navigation container — sheet, cover, popover, alert, dialog, inspector, `NavigationStack`, `NavigationSplitView`, `TabView`, pages, windows — is just a pluggable *rendering* of one of four state **shapes**:

| Shape | State | Lift | Binding | Reducer |
| --- | --- | --- | --- | --- |
| **Optional / modal** — 0-or-1, child created on present | `Item?` (or `Bool`) | `liftOptional` | ``StoreType/item(_:dismiss:)`` / ``StoreType/presence(_:dismiss:)`` | ``Behavior/navigationItem(_:action:allow:)`` |
| **Stack** — 0-to-N ordered | `[Route]` | `liftCollection` | ``StoreType/path(_:set:)`` | ``Behavior/navigationStack(_:action:allow:)`` |
| **Selection** — exactly 1-of-N, all alive | `Sel` (enum/id) | plain `lift` ×N | ``StoreType/selection(_:set:)`` | ``Behavior/navigationSelection(_:action:allow:)`` |
| **Scene set** — 0-to-N windows | keyed sub-states | element/dictionary projection | ``StoreType/hasScene(_:in:)`` + `WindowGroup(for:)` | ordinary open/close actions |

The rest is: pick the shape, drive its binding, resolve the destination through a router. No new dialect — the bindings feed *native* SwiftUI modifiers.

## Every container, by shape

### Optional / modal — `Item?` or `Bool`

Presentation and child lifetime are one fact: set the optional and the child exists and shows; clear it and it tears down. Use ``StoreType/item(_:dismiss:)`` when the presented content needs state (an `Identifiable` value), ``StoreType/presence(_:dismiss:)`` when a `Bool` suffices. Both only ever dispatch the *dismiss* action — presentation is driven by state, never by the binding.

```swift
// Sheet, full-screen cover, popover — item- or isPresented-driven, interchangeably:
.sheet(item: store.item(\.editing, dismiss: .dismissEditor)) { item in router.view(for: .editor(item.id)) }
.fullScreenCover(isPresented: store.presence(\.onboarding, dismiss: .finishOnboarding)) { router.view(for: .onboarding) }
.popover(item: store.item(\.tip, dismiss: .dismissTip)) { tip in TipView(tip) }

// Bottom sheet — a sheet whose content carries detents:
.sheet(isPresented: store.presence(\.filters, dismiss: .closeFilters)) {
    router.view(for: .filters).presentationDetents([.medium, .large])
}

// Inspector (iOS 17+) — Bool-driven:
.inspector(isPresented: store.presence(\.inspector, dismiss: .hideInspector)) { router.view(for: .inspector) }

// Single push via NavigationStack, without a path:
.navigationDestination(isPresented: store.presence(\.detail, dismiss: .popDetail)) { router.view(for: .detail) }

// Alert / confirmation dialog — present with `presence`/`item`; the BUTTONS dispatch their own actions:
.alert("Delete?", isPresented: store.presence(\.deleteConfirm, dismiss: .cancelDelete), presenting: store.state.deleteConfirm) { item in
    Button("Delete", role: .destructive) { store.dispatch(.confirmDelete(item.id)) }
    Button("Cancel", role: .cancel) { store.dispatch(.cancelDelete) }
}
.confirmationDialog("Sort", isPresented: store.presence(\.sortDialog, dismiss: .closeSort)) {
    Button("Newest") { store.dispatch(.sort(.newest)) }
    Button("Oldest") { store.dispatch(.sort(.oldest)) }
}
```

Behavior side: `liftOptional` (the child runs only while `.some`) or ``Behavior/navigationItem(_:action:allow:)`` for standard present/dismiss with an optional veto.

### Stack — `[Route]`

`NavigationStack(path:)` reflects the whole path; SwiftUI hands the binding the new path on any change, so one `setPath` action covers push, back-swipe, and pop-to-root. Destinations resolve through the router.

```swift
NavigationStack(path: store.path(\.path, set: NavAction.setPath)) {
    RootView(...)
        .navigationDestination(for: AppRoute.self) { route in router.view(for: route) }
}
```

Behavior side: `liftCollection` per element, plus ``Behavior/navigationStack(_:action:allow:)`` for `push`/`pop`/`popToRoot`/`setPath` (veto e.g. a pop while a form is dirty).

### Selection — 1-of-N, all children alive

Tabs, split view, and paged/carousel views keep every child mounted; only the selection changes. All children are lifted **unconditionally** (siblings in state). Unlike modal dismiss, selecting is a normal state change, so ``StoreType/selection(_:set:)`` dispatches on every change.

```swift
// Tabs:
TabView(selection: store.selection(\.tab, set: AppAction.selectTab)) {
    router.view(for: .home).tag(Tab.home)
    router.view(for: .search).tag(Tab.search)
}

// Paged / carousel — same selection, page style:
TabView(selection: store.selection(\.page, set: AppAction.selectPage)) { … }
    .tabViewStyle(.page)

// Split view — selection + column visibility (the latter is just a plain `binding`):
NavigationSplitView(columnVisibility: store.binding(\.columns, set: AppAction.setColumns)) {
    Sidebar(selection: store.selection(\.selectedItem, set: AppAction.select))   // optional selection
} detail: {
    router.view(for: .detail)
}
```

> A background/unselected child keeps running by default (that's the point of tabs). To pause one, add a supervisor keyed on the selection — it's your policy, not a framework default.

### Scene set — windows, one store

Multiple windows are still one store. Model open scenes as state (a dictionary of per-scene sub-states); each window projects its slice by id; open/close are ordinary actions; ``StoreType/hasScene(_:in:)`` tells a window body whether to render or dismiss.

```swift
var body: some Scene {
    WindowGroup { RootView(store: store, router: router) }
    WindowGroup(for: DocID.self) { $id in
        if let id, store.hasScene(id, in: \.documents) {
            Document.view(
                store: store.projection(key: id, actionReview: AppAction.document, stateDictionary: \.documents),
                environment: world.docEnv
            )
        }
    }
    // `Settings`, `MenuBarExtra`, `Window` follow the same single-store pattern.
}
```

`openWindow(value: DocID(…))` / `dismissWindow` are triggered by dispatching actions that add or remove a scene's sub-state — the window set is a function of state.

## Scope — declare the wiring once, drive both sides

A ``Scope`` captures how a child ``Feature`` embeds into the app store — action prism, state key path, environment narrowing — and derives **both** its lifted ``Scope/behavior`` and its ``Scope/view(from:world:)``. Constructing one is a **compile-time proof** the feature is wired; a missing state slot, action case, or env mapping is a compile error at the literal.

```swift
let detailScope = Scope(Detail.self, action: \.detail, state: \.detail, environment: \.detailEnv)
detailScope.behavior                          // Behavior<AppAction, AppState, World> — register it
detailScope.view(from: store, world: world)   // Detail's view, env supplied — call from the router
```

Register every scope's behavior in one place with ``Scopes`` so you can't forget to compose one:

```swift
let appBehavior = Scopes(
    homeScope.behavior,
    detailScope.behavior,
    Behavior.navigationStack(\.path, action: \.nav)   // + navigation reducers, logging, …
).behavior
let store = Store(initial: .init(), behavior: appBehavior, environment: world)
```

A child feature conforms with one line — `extension Detail: Feature {}` — where Swift infers the associated types from the members `@Feature` generates.

## Router — the WHAT (and the environment crux)

`Feature.view(store:environment:)` needs an environment, but a navigation destination runs inside the *environment-free* view body. A **router** — a value holding the store and the world — resolves that: its `@ViewBuilder view(for:)` switch builds each child (via ``Scope/view(from:world:)`` or directly), supplying the child's environment there. `some View` throughout — no `AnyView`.

```swift
@MainActor struct AppRouter {
    let store: MainStore
    let world: World
    let detailScope = Scope(Detail.self, action: \.detail, state: \.detail, environment: \.detailEnv)

    @ViewBuilder func view(for route: AppRoute) -> some View {
        switch route {
        case .detail: detailScope.view(from: store, world: world)   // env supplied here — crux resolved
        }
    }
}
```

A navigating view conforms to ``Routable`` and holds its router as a `let`, handed in at construction. Because the router builds every view, it re-hands itself at each construction — deterministic across the sheet/modal boundaries where SwiftUI's `@Environment` propagation is unreliable. The view body stays environment-free, and never names the child — the router does, so a route may resolve to a completely separate module (its own store slice and dependencies) without the presenting feature importing it.

```swift
struct HomeView: View, Routable {
    let viewStore: ViewStore<Home.State, Home.Action>
    let router: AppRouter
    var body: some View {
        List { … }.sheet(isPresented: viewStore.presence(\.route, dismiss: .dismiss)) {
            router.view(for: .detail)   // router supplies env — crux resolved
        }
    }
}
```

## Communication between features

A presented child talks back through the core ``Behavior/on(_:dispatch:reduce:)`` bridge: the child emits an action, a bridge routes it to the presenter (clearing the route, seeding state). It works identically for same-store and separate-store children — no direct coupling.

## Topics

- ``Scope``
- ``Scopes``
- ``Feature``
- ``Routable``
