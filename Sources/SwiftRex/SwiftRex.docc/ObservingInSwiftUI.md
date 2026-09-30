# Observing a Store in SwiftUI

Wire a store to SwiftUI by hand: who owns the view store, how child views receive it, where projections and buffers go, and how Observation and Combine differ.

## Overview

> Tip: Using `@Feature`? You can skip this article — the macro makes every decision below for you (the generated view owns the view store, buffers before the map when your `State` is `Equatable`, and `@BoundTo` injects the receiver). See <doc:Features>. This article is for wiring views to a store **manually**.

A ``StoreType`` can't be read — only observed (its ``StoreType/stateStream``) and dispatched to. A SwiftUI view reads a **`ViewStore`** instead: it follows any store, keeps one snapshot of the state, and records — per key path — what each view read. When the state changes it signals only the views that read something that changed, compared with `==`.

Everything in this article follows from one rule:

| | Code | Under every strategy |
|---|---|---|
| **One owner** builds the view store, once | `@OwnedStore var viewStore = appStore` | ✓ |
| **Every view below** receives it | `let viewStore: ViewStore<Action, State>` | ✓ |

The pieces, from the `SwiftRex.SwiftUI` product:

| Type | Role |
|---|---|
| `@OwnedStore` | The **owner**: a property wrapper that follows any store once per view identity (lazy, like `@StateObject`) and hands the view a `ViewStore`. |
| `ProjectionKeeper` | The owner, as a view: `ProjectionKeeper { make } content: { viewStore in … }` — for a body, a router, a list row. |
| `ViewStore<Action, State>` | The **receiver**: what views hold, as a plain `let`. Read through `viewStore.state`, dispatch with `viewStore.dispatch`. |
| `GranularTracking<Value>` | A position inside the state (`viewStore.state.player`) — hand it to a subview that only reads. |
| `IndivisibleTracking` | Marks a type that is read whole (strings, numbers, `Bool`, …; opt your own in). |
| `ViewStrategy` | How the view store signals SwiftUI: `.automatic` (default), `.observation`, `.combine`. |

## Owning the view store

A view store holds a snapshot, the record of what each view read, and its subscription to the upstream store — so it must be built **once**, by something that outlives body re-evaluations. Three ways, identical under every strategy:

**In a view — `@OwnedStore`** (the common case). The initial value is an autoclosure: it runs the first time the view appears, never on a re-initialisation.

```swift
struct RootView: View {
    @OwnedStore var viewStore = appStore          // any StoreType: a Store, a projection, a buffer…

    var body: some View { HomeView(viewStore: viewStore) }
}
```

When the upstream comes from the view's own inputs, assign it in `init`:

```swift
struct DetailScreen: View {
    @OwnedStore var viewStore: ViewStore<DetailAction, DetailState>

    init(appStore: some StoreType<AppAction, AppState>, id: Item.ID) {
        _viewStore = OwnedStore(wrappedValue: appStore.projection(
            action: { AppAction.detail(id, $0) },
            state: { $0.details[id] ?? .empty }
        ))
    }

    var body: some View { … }
}
```

To pick a strategy there, pass it after the upstream: `OwnedStore(wrappedValue: upstream, .combine)`. When the store is held as an existential (`any StoreType<A, S>`, the usual type of an app's store property), use the unlabeled form: `_viewStore = OwnedStore(store)`.

Handed a view store that already signals the same way — a router passing `viewStore.focus(…).transpose()` to a feature's view — an owner reuses it instead of building a second engine that re-follows the first.

**In the `App`**, which is initialised once — the same wrapper:

```swift
@main struct MyApp: App {
    @OwnedStore var viewStore = Store(initial: AppState(), behavior: appBehavior, environment: World.live)

    var body: some Scene {
        WindowGroup { RootView(viewStore: viewStore) }
    }
}
```

**Inline, in a body — `ProjectionKeeper`**, where a property wrapper can't go: a router's `switch`, a `ForEach` row, a sheet's content. It builds once per view identity; pass `id:` when the same position can come to show a *different* store.

```swift
.sheet(item: viewStore.binding(.state(\.editing).action(\.closeEditor))) { item in
    ProjectionKeeper(id: item.id) {
        appStore.projection(action: { .editor($0) }, state: { $0.editor ?? .empty })
    } content: { editor in
        EditorView(viewStore: editor)              // a ViewStore
    }
}
```

`ProjectionKeeper` is the composition *store → view store → view*, with ownership in the middle: `make` runs when the position first appears (or its `id` changes), `content` on every render with the same view store.

> Note: There is no public way to build a `ViewStore` directly — only the owners build one, so a body can't accidentally re-create it (and re-subscribe, and forget what its views read) on every render.

## Receiving it

A child never builds anything. It takes what the parent hands down, as a plain `let` — a re-initialised child gets the same view store back, so nothing is lost.

| The child… | Pass it | Its property |
|---|---|---|
| reads and dispatches on the whole state | the `ViewStore` | `let viewStore: ViewStore<A, S>` |
| only reads one region | a position: `viewStore.state.player` | `let player: GranularTracking<Player>` |
| reads a region and dispatches / binds into it | a focused view store: `viewStore.focus(.action(\.player).state(\.player))` | `let viewStore: ViewStore<PlayerAction, Player>` |
| is a row of a list | a row position: `ForEach(viewStore.state.each(\.songs)) { SongRow(song: $0) }` | `let song: GranularTracking<Song>` |
| only needs values | plain values | `let title: String` |

Reads are granular at any depth. A member whose type is `IndivisibleTracking` (strings, numbers, `Bool`, `Date`, `UUID`, `URL`, `Data`, optionals and arrays of those…) comes back as the value; anything else comes back as a position you keep reading into:

```swift
Text(viewStore.state.title)                   // depends on \.title
Text(viewStore.state.player.title)            // depends on \.player.title only
viewStore.state.player                        // GranularTracking<Player> — nothing recorded yet
viewStore.state.player.value                  // the whole Player — depends on \.player
extension Status: IndivisibleTracking {}      // opt a small value in to be read whole
```

**Pass positions down, not values.** A child that receives `viewStore.state.transport` depends only on what *it* reads, so a field that changes ten times a second redraws the one small view that shows it — no hand-split sub-stores:

```swift
struct PlayerScreen: View {
    let viewStore: ViewStore<PlayerAction, PlayerState>

    var body: some View {
        Console(mixer: viewStore.state.mixer)            // untouched by playhead ticks
        Playhead(transport: viewStore.state.transport)   // redraws on every tick, alone
    }
}
```

**Focusing** gives a child its own `ViewStore` of a key-path slice: it reads through the parent's view store (no new subscription, no owner needed — cheap to create in a body) and dispatches through its own action lane. Use it when the child dispatches or binds, not only reads.

**Dispatch intent, don't read in closures.** An action closure has no business reading the state — send what the user meant and let the reducer, which has the state, decide: `Button("Mark") { viewStore.dispatch(.markAtPlayhead) }`, not `.mark(at: <current position>)`. The view then depends on nothing it doesn't show.

## Projecting, buffering, following

Stores compose declaratively: each one *follows* the one below through its ``StoreType/stateStream``. Nothing runs until something observes, and following a store never registers a view dependency.

| Operator | Does | Costs per upstream change, per observer |
|---|---|---|
| `projection(action:state:)` | narrows the types; keeps nothing | the map, once |
| `buffer()` | passes a change on only when `!=` | one `==` |
| a view store (`@OwnedStore` / `ProjectionKeeper`) | keeps a snapshot; signals the views whose paths changed | the changed paths |

A view store already *is* a buffer on its output — it only signals what changed, per path — so the one placement decision left is **before a map**: `buffer()` there skips the map entirely when its input didn't change. Pick the recipe by what the view needs:

| The view needs | Owner | Notes |
|---|---|---|
| the app state as it is | `@OwnedStore var viewStore = appStore` | reads are granular; no projection at all |
| a slice (`\.player`) | own the parent once, pass `viewStore.state.player` / `viewStore.focus(…)` down | no new subscription, no extra work |
| a derived view state (a map) | `@OwnedStore var viewStore = appStore.projection(action: …, state: makeViewState)` | the map runs once per upstream change |
| a derived view state, and the map is expensive or the app is busy | `@OwnedStore var viewStore = appStore.buffer().projection(…)` | the map runs only when its input changed — needs the input `Equatable` |
| a derived view state of one feature's slice | `appStore.projection(action: …, state: \.feature).buffer().projection(action: { $0 }, state: makeViewState)` | slice → dedup on the slice → map |
| a derived view state *from a view store* | `@OwnedStore var detail = viewStore.projection(action: …, state: …)` | the child follows the parent's already-filtered changes |

Focusing through a **key path** reads through the same view store for free. Projecting through a **closure** can't — nothing can see into an arbitrary function — so the result is a plain ``StoreProjection``, which you own again with `@OwnedStore` or `ProjectionKeeper`. The types enforce this: a `StoreProjection` has no `state` to read and no bindings.

## Choosing the signal: Observation or Combine

The strategy is chosen **once, by the owner**, and changes only how the view store tells SwiftUI something changed. Receivers, positions, bindings and bodies are identical under every strategy.

| Strategy | Signal | Redraws | Where it runs |
|---|---|---|---|
| `.automatic` (default) | Observation on iOS 17 / macOS 14 / tvOS 17 / watchOS 10, Combine below | — | everywhere |
| `.observation` | Observation-framework registrar, per changed path | only the views that read a changed path | falls back to Combine below iOS 17 |
| `.combine` | one `objectWillChange`, sent only when a path some view read has changed | every view holding the view store or a position of it | everywhere, including iOS 17+ |

Owner × strategy, spelled out — the receiving side never changes:

| Owner | Observation (`.automatic` on iOS 17+) | Combine (`.automatic` below 17, or forced) | Receivers |
|---|---|---|---|
| a view | `@OwnedStore var viewStore = appStore` | `@OwnedStore(.combine) var viewStore = appStore` | `let viewStore: ViewStore<…>` |
| the `App` | `@OwnedStore var viewStore = Store(…)` | `@OwnedStore(.combine) var viewStore = Store(…)` | `let viewStore: ViewStore<…>` |
| a body / router / row | `ProjectionKeeper { upstream } content: { … }` | `ProjectionKeeper(strategy: .combine) { upstream } content: { … }` | `let viewStore: ViewStore<…>` |

Force Combine to sidestep the Observation framework. There is no `@ObservedObject` anywhere: `ViewStore` and `GranularTracking` are `DynamicProperty`s that carry the Combine subscription themselves, so a plain `let` re-renders under Combine too (and the subscription simply never fires under Observation).

Either way, a dispatch reaches the view store synchronously on the main actor — store, projections, buffers, view store — so `withAnimation { viewStore.dispatch(.toggle) }` animates.

## Bindings and navigation

The binding and presentation helpers exist only on `ViewStore`. On a plain `Store` or `StoreProjection` they don't compile: a binding SwiftUI can't observe would never update. They read granularly too — `presence(.state(\.detail))` redraws on the presence edge, not on every change inside `detail`.

```swift
struct RootView: View {
    @OwnedStore var viewStore = appStore

    var body: some View {
        NavigationStack(path: viewStore.binding(.state(\.path).action(review: AppAction.setPath))) {
            HomeView(viewStore: viewStore)
                .navigationDestination(for: Route.self) { route in destination(route) }
        }
        .sheet(isPresented: viewStore.binding(.state(\.settings).action(\.closeSettings))) {
            // `settings` is optional state: present while it exists, the child follows its own state.
            if let settings = viewStore.focus(.action(\.settings).state(\.settings)).transpose() {
                SettingsView(viewStore: settings)
            }
        }
    }

    @ViewBuilder func destination(_ route: Route) -> some View {
        switch route {
        case .detail:
            if let detail = viewStore.focus(.action(\.detail).state(\.detail)).transpose() {
                DetailView(viewStore: detail)
            }
        }
    }
}
```

`transpose()` turns a `ViewStore<T?>` (or `ViewStore<Presentation<T>>`) into a `ViewStore<T>?` that exists exactly while the state does — a view store on the same engine, so no owner is needed. The caller depends on the **presence edge only**; the child reads its own state granularly, and holds its last value while SwiftUI animates it away. For lanes no key path expresses (an enum case, the top of a stack), `viewStore.transpose(action:state:)` takes the closures directly and returns a `StoreProjection?` for a feature's view to own.

For routers built on ``Relay/Scope`` and features, see <doc:Navigation> and <doc:NavigationEndToEnd>.

## Following a store outside SwiftUI

Anything that isn't a SwiftUI view follows a store through its ``StoreType/stateStream``: the current state immediately, then every new state, on the main actor.

```swift
let token = store.stateStream.map(\.username).removeDuplicates().observe { nameLabel.text = $0 }
for await state in store.stateStream { … }                    // AsyncSequence, latest value first
store.stateStream.sink { … }.store(in: &cancellables)          // a Combine Publisher (SwiftRex.Combine)
```

Keep the returned ``UISubscriptionToken`` for as long as you follow; releasing it stops delivery immediately.

An optional child outside SwiftUI is just state: follow its presence and present or dismiss on the edge, handing the child screen an ordinary projection of the slot:

```swift
token = store.stateStream
    .map { $0.editor != nil }
    .removeDuplicates()
    .observe { isShown in isShown ? presentEditor() : dismissEditor() }
```

The RxSwift, ReactiveSwift and ReactiveConcurrency products make the stream an `ObservableType`, a `SignalProducerConvertible` and `asPublisher` respectively.

## Pitfalls

- **Reading `viewStore.state.value`** — a coarse read: the view depends on *every* change. Read the paths you need (`viewStore.state.title`).
- **A state member named like a position member** (`value`, `each`, `id`, …) is shadowed — read it with `viewStore.state[dynamicMember: \.value]`.
- **Non-`Equatable` values** can't be compared, so a view reading one redraws on every change that reaches the view store. Make view-facing types `Equatable`.
- **An enum or small value read as a position** — `viewStore.state.status.value` works; `extension Status: IndivisibleTracking {}` lets you write `viewStore.state.status`.
- **Reading state to decide what to dispatch** — dispatch the intent instead (`.markAtPlayhead`); the reducer has the state.
- **Owning a view store in a `body`** — use `ProjectionKeeper` there, never a fresh `@OwnedStore` view per render with a changing identity.

## See Also

- <doc:StoresAtAGlance>
- <doc:Features>
- <doc:Navigation>
- ``StoreProjection``
- ``StoreBuffer``
