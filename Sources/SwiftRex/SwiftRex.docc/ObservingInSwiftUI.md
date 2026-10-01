# Observing a Store in SwiftUI

Wire a store to SwiftUI by hand: who owns the view store, how child views receive it, where projections and buffers go, and how Observation and Combine differ.

## Overview

> Tip: Using `@Feature`? You can skip this article — the macro makes every decision below for you (the generated view owns the view store, buffers before the map when your `State` is `Equatable`, and `@BoundTo` injects the receiver). See <doc:Features>. This article is for wiring views to a store **manually**.

A ``StoreType`` can't be read — only observed (its ``StoreType/stateStream``) and dispatched to. A SwiftUI view reads a **`ViewStore`** instead: it follows any store, keeps one snapshot of the state, and records — per key path — what each view read. When the state changes it signals only the views that read something that changed, compared with `==`.

Everything in this article follows from two rules:

**Pure until the leaf.** Stores compose as pure stages — ``Store`` → ``StoreProjection`` / ``StoreBuffer`` / ``StoreCollectionFocus`` / ``StoreOptionalFocus`` → … — each following the one before, keeping nothing a parent holds. The `ViewStore` is the leaf where that ends: it owns a snapshot (a cache) and does the observation work, which are effects. Deriving anything from a view store — `projection`, `transpose` — gives a pure stage again, built on the view store's pure side.

**You make a view store explicitly, keep it once, and hand it down.**

| | Code | Under every strategy |
|---|---|---|
| **Make** a view store from any store | `store.viewStore()` — a `Store`, a projection, a buffer, a transposed slot | ✓ |
| **Keep** it, once, in the view that uses it | `@OwnedStore var viewStore = store.viewStore()` | ✓ |
| **Every view below** receives it | `let viewStore: ViewStore<Action, State>` | ✓ |

So the questions are always answered the same way: *derived* → a pure stage; *to observe a stage* → `.viewStore()`, kept where it's made; *given by a parent* → `let`.

The pieces, from the `SwiftRex.SwiftUI` product:

| Type | Role |
|---|---|
| `.viewStore(_:)` | Makes a `ViewStore` from any ``StoreType`` — the only way to make one. Takes the `ViewStrategy` (`.automatic` by default). |
| `@OwnedStore` | Keeps a `ViewStore` for the life of the view (lazy, like `@StateObject`) — nothing more. |
| `ViewStore<Action, State>` | What views hold, as a plain `let`. Read through `viewStore.state`, dispatch with `viewStore.dispatch`. |
| `GranularTracking<Value>` | A position inside the state (`viewStore.state.player`) — hand it to a subview that only reads. |
| `IndivisibleTracking` | Marks a type that is read whole (strings, numbers, `Bool`, …; opt your own in). |
| `ViewStrategy` | How the view store signals SwiftUI: `.automatic` (default), `.observation`, `.combine`. |

## Making and keeping the view store

A view store holds a snapshot, the record of what each view read, and its subscription to the upstream store — so it's made **once**, where something that outlives body re-evaluations keeps it. `.viewStore()` makes it; `@OwnedStore` only keeps what it's given — always in the view that uses it.

**In a view — `@OwnedStore`** (the common case). The initial value is an autoclosure: it runs the first time the view appears, never on a re-initialisation.

```swift
struct DetailScreen: View {
    @OwnedStore var viewStore: ViewStore<DetailAction, DetailState>

    init(appStore: some StoreType<AppAction, AppState>, id: Item.ID) {
        _viewStore = OwnedStore(wrappedValue: appStore
            .projection(action: { AppAction.detail(id, $0) }, state: { $0.details[id] ?? .empty })
            .viewStore())
    }

    var body: some View { … }
}
```

Pick the signal where the view store is made: `store.viewStore(.combine)`. An existential store (`any StoreType<A, S>`) makes one the same way.

**In the `App`**, keep the two apart. The real ``Store`` runs the app and is never observed — create it once, in the shell, and keep a plain reference (deep links, scene delegates and effects dispatch to it). The root view keeps the view store made from it:

```swift
@main struct MyApp: App {
    let store = Store(initial: AppState(), behavior: appBehavior, environment: World.live)   // runs the app

    var body: some Scene {
        WindowGroup { RootView(store: store) }
    }
}

struct RootView: View {
    @OwnedStore var viewStore: ViewStore<AppAction, AppState>                              // the leaf, kept here

    init(store: Store<AppAction, AppState, World>) {
        _viewStore = OwnedStore(wrappedValue: store.viewStore())
    }

    var body: some View { HomeView(viewStore: viewStore) }
}
```

**In a body — hand the stage to the child view**, which keeps its own view store: a router's `switch`, a `ForEach` row, a sheet's content. A stage is a pure value, cheap to build on every render; the child's `@OwnedStore` makes the view store from it only the first time that view appears.

```swift
.sheet(item: viewStore.binding(.state(\.editing).action(\.closeEditor))) { _ in
    if let editor = viewStore.traverse(.action(\.editor).state(\.editor)) {
        EditorView(store: editor)
    }
}

struct EditorView: View {
    @OwnedStore var viewStore: ViewStore<EditorAction, EditorState>
    init(store: some StoreType<EditorAction, EditorState>) { _viewStore = OwnedStore(wrappedValue: store.viewStore()) }
    var body: some View { … }
}
```

Give the child an `.id(…)` when the same position can come to show a *different* store (a sheet for another item): a new identity makes a new view store.

> Note: Make a view store only where it's kept. `.viewStore()` alone in a `body` makes a new one on every render — a new subscription, and the record of what its views read forgotten.

## Receiving it

A child never builds anything. It takes what the parent hands down, as a plain `let` — a re-initialised child gets the same view store back, so nothing is lost.

| The child… | Pass it | Its property |
|---|---|---|
| reads and dispatches on the whole state | the `ViewStore` | `let viewStore: ViewStore<A, S>` |
| only reads one region | a position: `viewStore.state.player` | `let player: GranularTracking<Player>` |
| reads a region and dispatches / binds into it | a stage: `PlayerView(store: viewStore.projection(.action(\.player).state(\.player)))` | `@OwnedStore var viewStore: ViewStore<PlayerAction, Player>`, made from it in `init` |
| is a row that dispatches or binds | a stage per row: `ForEach(viewStore.each(.action(\.row).state(\.rows))) { RowView(store: $0) }` | `@OwnedStore var viewStore: ViewStore<RowAction, Row>`, made from it in `init` |
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

**A child that dispatches or binds gets its own view store.** Derive a pure stage from yours — `viewStore.projection(scope)` for a slice, `viewStore.traverse(scope)` for an optional, `viewStore.traverse(scope, element: id)` for a row — and make its `.viewStore()` where the child keeps it (a feature's view does it for you). The child's view store follows its own stage, diffs its own snapshot, and redraws only for what *it* reads; the parent holds nothing for it.

**Dispatch intent, don't read in closures.** An action closure has no business reading the state — send what the user meant and let the reducer, which has the state, decide: `Button("Mark") { viewStore.dispatch(.markAtPlayhead) }`, not `.mark(at: <current position>)`. The view then depends on nothing it doesn't show.

## Projecting, buffering, following

Stores compose declaratively: each one *follows* the one below through its ``StoreType/stateStream``. Nothing runs until something observes, and following a store never registers a view dependency.

| Operator | Does | Costs per upstream change, per observer |
|---|---|---|
| `projection(action:state:)` | narrows the types; keeps nothing | the map, once |
| `buffer()` | passes a change on only when `!=` | one `==` |
| a view store (`.viewStore()`, kept by `@OwnedStore`) | keeps a snapshot; signals the views whose paths changed | the changed paths |

A view store already *is* a buffer on its output — it only signals what changed, per path — so the one placement decision left is **before a map**: `buffer()` there skips the map entirely when its input didn't change. Pick the recipe by what the view needs:

| The view needs | Owner | Notes |
|---|---|---|
| the app state as it is | `@OwnedStore var viewStore = appStore.viewStore()` | reads are granular; no projection at all |
| a slice (`\.player`) that a subview only reads | own the parent once, pass `viewStore.state.player` down | no new subscription, no extra work |
| a slice a subview dispatches into or binds | `PlayerView(store: viewStore.projection(.action(\.player).state(\.player)))`, which keeps `.viewStore()` of it | the child's own view store |
| a derived view state (a map) | `@OwnedStore var viewStore = appStore.projection(action: …, state: makeViewState).viewStore()` | the map runs once per upstream change |
| a derived view state, and the map is expensive or the app is busy | `@OwnedStore var viewStore = appStore.buffer().projection(…).viewStore()` | the map runs only when its input changed — needs the input `Equatable` |
| a derived view state of one feature's slice | `appStore.projection(action: …, state: \.feature).buffer().projection(action: { $0 }, state: makeViewState)` | slice → dedup on the slice → map |
| a derived view state *from a view store* | `@OwnedStore var detail = viewStore.projection(action: …, state: …).viewStore()` | the child follows the parent's pure chain, not its snapshot |

A pure stage has no `state` to read and no bindings — the types make you call `.viewStore()` before you can observe it.

## Choosing the signal: Observation or Combine

The strategy is chosen **once, where the view store is made** (`.viewStore(.combine)`), and changes only how the view store tells SwiftUI something changed. Receivers, positions, bindings and bodies are identical under every strategy.

| Strategy | Signal | Redraws | Where it runs |
|---|---|---|---|
| `.automatic` (default) | Observation on iOS 17 / macOS 14 / tvOS 17 / watchOS 10, Combine below | — | everywhere |
| `.observation` | Observation-framework registrar, per changed path | only the views that read a changed path | falls back to Combine below iOS 17 |
| `.combine` | one `objectWillChange`, sent only when a path some view read has changed | every view holding the view store or a position of it | everywhere, including iOS 17+ |

Owner × strategy, spelled out — the receiving side never changes:

| Owner | Observation (`.automatic` on iOS 17+) | Combine (`.automatic` below 17, or forced) | Receivers |
|---|---|---|---|
| a view | `@OwnedStore var viewStore = appStore.viewStore()` | `@OwnedStore var viewStore = appStore.viewStore(.combine)` | `let viewStore: ViewStore<…>` |
| the root view (the `App` keeps the real `Store`) | `_viewStore = OwnedStore(wrappedValue: store.viewStore())` | `_viewStore = OwnedStore(wrappedValue: store.viewStore(.combine))` | `let viewStore: ViewStore<…>` |
| a child handed a stage | `_viewStore = OwnedStore(wrappedValue: store.viewStore())` | `_viewStore = OwnedStore(wrappedValue: store.viewStore(.combine))` | `let viewStore: ViewStore<…>` |

Force Combine to sidestep the Observation framework. There is no `@ObservedObject` anywhere: `ViewStore` and `GranularTracking` are `DynamicProperty`s that carry the Combine subscription themselves, so a plain `let` re-renders under Combine too (and the subscription simply never fires under Observation).

Either way, a dispatch reaches the view store synchronously on the main actor — store, projections, buffers, view store — so `withAnimation { viewStore.dispatch(.toggle) }` animates.

## Bindings and navigation

The binding and presentation helpers exist only on `ViewStore`. A two-way binding over an `Equatable` value dispatches only real changes — SwiftUI sometimes writes a binding twice for one gesture (a list row tap writes its selection twice), and an equal write is dropped. On iPhone, make `List(selection:)` rows `NavigationLink(value:)`: a `.tag`ged row selects only in edit mode there. On a plain `Store` or `StoreProjection` they don't compile: a binding SwiftUI can't observe would never update. They read granularly too — `presence(.state(\.detail))` redraws on the presence edge, not on every change inside `detail`.

```swift
struct RootView: View {
    @OwnedStore var viewStore = appStore.viewStore()

    var body: some View {
        NavigationStack(path: viewStore.binding(.state(\.path).action(review: AppAction.setPath))) {
            HomeView(viewStore: viewStore)
                .navigationDestination(for: Route.self) { route in destination(route) }
        }
        .sheet(isPresented: viewStore.binding(.state(\.settings).action(\.closeSettings))) {
            // `settings` is optional state: present while it exists; the child keeps a view store of its own.
            if let settings = viewStore.traverse(.action(\.settings).state(\.settings)) {
                SettingsView(store: settings)            // @OwnedStore var viewStore = store.viewStore(), in its init
            }
        }
    }

    @ViewBuilder func destination(_ route: Route) -> some View {
        switch route {
        case .detail:
            if let detail = viewStore.traverse(.action(\.detail).state(\.detail)) {
                DetailView(store: detail)
            }
        }
    }
}
```

`traverse(scope)` reads whether the slot is there — a read, so it's on the view store, and the caller depends on the **presence edge only** — and returns a ``StoreOptionalFocus``, a pure stage of the unwrapped value that holds its last value while SwiftUI animates the child away. `traverse` is map then `transpose`: through the scope, then `T?` into a store of `T`. Hand the stage to the child, which keeps its own view store (a feature's `view(store: detail, environment: …)` does it for you). The same works for a `Presentation` slot, a collection element (`traverse(scope, element: id)`), and lanes no key path expresses (`traverse(action:state:)`); a loop over every element uses `each(scope)`.

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
- **Making a view store in a `body`** — never: it makes a new one per render. Hand the stage to a child view, whose `@OwnedStore` makes it once.

## See Also

- <doc:StoresAtAGlance>
- <doc:Features>
- <doc:Navigation>
- ``StoreProjection``
- ``StoreBuffer``
