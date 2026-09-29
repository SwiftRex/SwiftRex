# Observing a Store in SwiftUI

Wire a store to SwiftUI by hand: who owns the observed store, how child views receive it, where projections and buffers go, and how Observation and Combine differ.

## Overview

> Tip: Using `@Feature`? You can skip this article — the macro makes every decision below for you (the generated view owns the store, buffers before the map when your `State` is `Equatable`, and `@BoundTo` injects the receiver). See <doc:Features>. This article is for wiring views to a store **manually**.

A ``Store`` runs your app; it isn't something SwiftUI can observe. A view reads an **observed store** instead — an `ObservableStore` wrapped around any ``StoreType`` — which keeps one snapshot of the state and records, per key path, what each view read. When the state changes it signals only the views that read something that changed, compared with `==`.

Everything in this article follows from one rule:

| | Code | Under every strategy |
|---|---|---|
| **One owner** builds the observed store, once | `@ObservedStore var store = appStore` | ✓ |
| **Every view below** receives it | `let store: ViewStore<Action, State>` | ✓ |

The pieces, from the `SwiftRex.SwiftUI` product:

| Type | Role |
|---|---|
| `@ObservedStore` | The **owner**: a property wrapper observing any store once per view identity (lazy, like `@StateObject`). |
| `ObservableStoreHost` | The owner, as a view: `ObservableStoreHost { make } content: { store in … }` — for a body, a router, a list row. |
| `ViewStore<Action, State>` | The **receiver**: what views hold, as a plain `let`. |
| `StateNode<Store, Value>` | A position inside the state (`store.player`) — hand it to a subview that only reads. |
| `ScopedStore` | A key-path slice with its own action lane (`store.player.scoped(action: …)`) — hand it to a subview that also dispatches or binds. |
| `ObservableStore` | The class underneath; you rarely name it. |
| `ViewStrategy` | How the store signals SwiftUI: `.automatic` (default), `.observation`, `.combine`. |

## Owning the observed store

The observed store *is* the buffer — its snapshot, its record of what each view read, and its subscription to the upstream store — so it must be built **once**, by something that outlives body re-evaluations. Three ways, identical under every strategy:

**In a view — `@ObservedStore`** (the common case). The initial value is an autoclosure: it runs the first time the view appears, never on a re-initialisation.

```swift
struct RootView: View {
    @ObservedStore var store = appStore          // any StoreType: a Store, a projection, a buffer…

    var body: some View { HomeView(store: store) }
}
```

When the upstream comes from the view's own inputs, assign it in `init`:

```swift
struct DetailScreen: View {
    @ObservedStore var store: ViewStore<DetailAction, DetailState>

    init(appStore: some StoreType<AppAction, AppState>, id: Item.ID) {
        _store = ObservedStore(wrappedValue: appStore.projection(
            action: { AppAction.detail(id, $0) },
            state: { $0.details[id] ?? .empty }
        ))
    }

    var body: some View { … }
}
```

To pick a strategy there, pass it after the upstream: `ObservedStore(wrappedValue: upstream, .combine)`.

**In the `App`**, which is initialised once — the same wrapper:

```swift
@main struct MyApp: App {
    @ObservedStore var store = Store(initial: AppState(), behavior: appBehavior, environment: World.live)

    var body: some Scene {
        WindowGroup { RootView(store: store) }
    }
}
```

**Inline, in a body — `ObservableStoreHost`**, where a property wrapper can't go: a router's `switch`, a `ForEach` row, a sheet's content. It builds once per view identity; pass `id:` when the same position can come to show a *different* store.

```swift
.sheet(item: store.item(.state(\.editing), dismiss: .closeEditor)) { item in
    ObservableStoreHost(id: item.id) {
        appStore.projection(action: { .editor($0) }, state: { $0.editor ?? .empty }).observable()
    } content: { editor in
        EditorView(store: editor)                  // a ViewStore
    }
}
```

> Warning: Never build an observed store in a `body` — `Child(store: ViewStore(appStore.observable()))`. Every re-evaluation allocates a new store, subscribes it upstream and throws away everything the old one recorded. `@State var store = appStore.observable()` in an ordinary view has the same cost in a quieter form: `@State` keeps the first instance, but Swift still evaluates the initial value on every `init`. `@ObservedStore` and the host evaluate their closure only when there's no store yet.

## Receiving it

A child never builds anything. It takes what the parent hands down, as a plain `let` — a re-initialised child gets the same store back, so nothing is lost.

| The child… | Pass it | Its property |
|---|---|---|
| reads and dispatches on the whole state | the `ViewStore` | `let store: ViewStore<A, S>` |
| only reads one region | a node: `store.player` | `let player: StateNode<ViewStore<A, S>, Player>` |
| reads a region and dispatches / binds into it | a scoped store: `store.player.scoped(action: .action(\.player))` | `let store: ScopedStore<A, S, PlayerAction, Player>` |
| is a row of a list | a row node: `ForEach(store.each(\.songs)) { SongRow(song: $0) }` | `let song: StateNode<ViewStore<A, S>, Song>` |
| only needs values | plain values | `let title: String` |

Reads are granular at any depth. A member whose type is an `ObservableLeaf` (strings, numbers, `Bool`, `Date`, `UUID`, `URL`, `Data`, optionals and arrays of those…) comes back as the value; anything else comes back as a node you keep reading into:

```swift
Text(store.title)                       // depends on \.title
Text(store.player.title)                // depends on \.player.title only
store.player                            // StateNode<…, Player> — nothing recorded yet
store.player.value                      // the whole Player — depends on \.player
extension Status: ObservableLeaf {}     // opt a small value in to be read whole: store.status is now a Status
```

**Pass nodes down, not values.** A child that receives `store.transport` depends only on what *it* reads, so a field that changes ten times a second redraws the one small view that shows it — no hand-split sub-stores:

```swift
struct PlayerScreen: View {
    let store: ViewStore<PlayerAction, PlayerState>

    var body: some View {
        Console(mixer: store.mixer)            // untouched by playhead ticks
        Playhead(transport: store.transport)   // redraws on every tick, alone
    }
}
```

In an action closure, read with `peek` so neither the closure nor the view depends on the value: `Button("Mark") { store.dispatch(.mark(at: store.peek(\.transport.position))) }`.

## Projecting, buffering, observing

Three operators, each with one job:

| Operator | Does | Costs per upstream change |
|---|---|---|
| `projection(action:state:)` | narrows the types; lazy, keeps nothing | runs the map on **every read** |
| `buffer()` | keeps a snapshot; passes a change on only when `!=` | one `==` |
| observing (`@ObservedStore` / host) | keeps a snapshot; signals the views whose paths changed | the map once (if upstream is a projection) + the changed paths |

Observing already *is* a buffer on its output — it only signals what changed, per path — so the one placement decision left is **before a map**: `buffer()` there skips the map entirely when its input didn't change. Pick the recipe by what the view needs:

| The view needs | Owner | Notes |
|---|---|---|
| the app state as it is | `@ObservedStore var store = appStore` | reads are granular; no projection at all |
| a slice (`\.player`) | observe the parent once, pass `store.player` / `.scoped(…)` down | no new subscription, no extra work |
| a derived view state (a map) | `@ObservedStore var s = appStore.projection(action: …, state: makeViewState)` | the map runs once per upstream change |
| a derived view state, and the map is expensive or the app is busy | `@ObservedStore var s = appStore.buffer().projection(…)` | the map runs only when its input changed — needs the input `Equatable` |
| a derived view state of one feature's slice | `appStore.projection(action: …, state: \.feature).buffer().projection(action: { $0 }, state: makeViewState)` | slice → dedup on the slice → map |
| a derived view state *from an already observed store* | `@ObservedStore var detail = store.projection(action: …, state: …)` (where `store` is a `ViewStore`) | observe → project → observe: the child subscribes to the parent's already-filtered changes |

Projecting through a **key path** stays observable for free (a node, a scoped store). Projecting through a **closure** can't — the store can't see into an arbitrary function — so the result is a plain ``StoreProjection``, and you observe it again with `@ObservedStore` or the host. The types enforce this: bindings don't exist on a `StoreProjection`.

## Choosing the signal: Observation or Combine

The strategy is chosen **once, by the owner**, and changes only how the store tells SwiftUI something changed. Receivers, nodes, bindings and bodies are identical under every strategy.

| Strategy | Signal | Redraws | Where it runs |
|---|---|---|---|
| `.automatic` (default) | Observation on iOS 17 / macOS 14 / tvOS 17 / watchOS 10, Combine below | — | everywhere |
| `.observation` | Observation-framework registrar, per changed path | only the views that read a changed path | falls back to Combine below iOS 17 |
| `.combine` | one `objectWillChange`, sent only when a path some view read has changed | every view observing the store | everywhere, including iOS 17+ |

Owner × strategy, spelled out — the receiving side never changes:

| Owner | Observation (`.automatic` on iOS 17+) | Combine (`.automatic` below 17, or forced) | Receivers |
|---|---|---|---|
| a view | `@ObservedStore var store = appStore` | `@ObservedStore(.combine) var store = appStore` | `let store: ViewStore<…>` |
| the `App` | `@ObservedStore var store = Store(…)` | `@ObservedStore(.combine) var store = Store(…)` | `let store: ViewStore<…>` |
| a body / router / row | `ObservableStoreHost { upstream.observable() } content: { … }` | `ObservableStoreHost { upstream.observable(.combine) } content: { … }` | `let store: ViewStore<…>` |

Force Combine when something listens to `objectWillChange` directly, or to sidestep the Observation framework. There is no `@ObservedObject` anywhere: `ViewStore`, `StateNode` and `ScopedStore` are `DynamicProperty`s that carry the Combine subscription themselves, so a plain `let` re-renders under Combine too (and the subscription simply never fires under Observation).

## Bindings and navigation

The binding and presentation helpers exist only on observed stores — `ViewStore`, `ScopedStore`, `ObservableStore`. On a plain `Store` or `StoreProjection` they don't compile: a binding SwiftUI can't observe would never update. They read granularly too — `presence(.state(\.detail))` redraws on the presence edge, not on every change inside `detail`.

```swift
struct RootView: View {
    @ObservedStore var store = appStore

    var body: some View {
        NavigationStack(path: store.binding(.state(\.path), dispatch: .action(review: AppAction.setPath))) {
            HomeView(store: store)
                .navigationDestination(for: Route.self) { route in destination(route) }
        }
        .sheet(isPresented: store.presence(.state(\.settings), dismiss: .closeSettings)) {
            if let settings = store.settings.unwrapped() {          // `settings` is optional state
                SettingsView(store: settings.scoped(action: .action(\.settings)))
            }
        }
    }

    @ViewBuilder func destination(_ route: Route) -> some View {
        switch route {
        case .detail:
            // An optional child: depend on its presence only; the child observes its own state.
            if let detail = store.detail.scoped(action: .action(\.detail)).transpose() {
                ObservableStoreHost { detail.observable() } content: { DetailView(store: $0) }
            }
        }
    }
}
```

For routers built on ``Relay/Scope`` and features, see <doc:Navigation> and <doc:NavigationEndToEnd>.

## Pitfalls

- **Reading `store.state`** — a coarse read: the view depends on *every* change. Read the paths you need (`store.title`).
- **A state member named like a store member** (`state`, `dispatch`, `each`, `binding`, `item`, `presence`, …) is shadowed — read it with `store.read(\.item)`.
- **Non-`Equatable` values** can't be compared, so a view reading one redraws on every change that reaches the store. Make view-facing types `Equatable`.
- **An enum or small value read as a node** — `store.status.value` works; `extension Status: ObservableLeaf {}` lets you write `store.status`.
- **Capturing a fast-changing value in a closure** makes the view depend on it and rebuilds the closure every tick. Read it inside the closure with `store.peek(\.transport.position)`.
- **Building an observed store in a `body`**, or in `@State`'s initial value of an ordinary view — see *Owning the observed store*.

## See Also

- <doc:Features>
- <doc:Navigation>
- ``StoreProjection``
- ``StoreBuffer``
