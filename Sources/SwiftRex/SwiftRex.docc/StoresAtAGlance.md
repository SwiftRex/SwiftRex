# Stores at a Glance

Every type that behaves like a store, which module it lives in, what it's for — and exactly which views redraw when state changes, under Observation and under Combine.

## Overview

SwiftRex has one store that *runs* the app and several that *follow* it: they take actions and describe state over time. Only one of them can be **read** — the `ViewStore`, the store SwiftUI views hold. This page is the map; each row links to the type or article that goes deep.

> Tip: With `@Feature` you only ever *write* two of these: the ``Store`` (once, at launch) and the injected `viewStore` (a `ViewStore`). Everything else is built for you. See <doc:Features>.

## The index

### The contract

| Type | Kind | Module | What it is |
|---|---|---|---|
| ``StoreType`` | protocol | `SwiftRex` | Anything with `dispatch(_:source:)` and a ``StoreType/stateStream``. **No `state` property**: a store is followed, not read. Every row below conforms. |
| ``StateStream`` | struct | `SwiftRex` | The state over time, lazy, on the main actor: `observe { }` delivers the current state *during the call*, then every new state. Operators `map`, `removeDuplicates`; an `AsyncSequence`; a Combine `Publisher` (and more, per bridge). |
| ``UISubscriptionToken`` | class | `SwiftRex` | What `observe` returns. Keep it to keep following; `cancel()` or releasing it stops delivery immediately. |

### Running and shaping state (core — every platform)

| Type | Kind | Keeps a state copy? | Use it to |
|---|---|---|---|
| ``Store`` | class | owns *the* state (privately) | run the app: reducers, effects, the one source of truth. Build it once, at launch. |
| ``StoreProjection`` | struct | no — maps each state for each observer | narrow action/state types (`store.projection(action:state:)`, or through a ``Relay/Scope``). |
| ``StoreBuffer`` | struct | no — each observer remembers its previous value | skip redundant work: passes a change on only when `!=`. Put it **before** a costly map. |
| `TestStore` | class | owns a test state, readable (`state`) | exhaustive tests (`SwiftRex.Testing`). |
| ``StoreOf`` / ``StoreTypeOf`` | type aliases | — | spell `Store<A, S, E>` / `any StoreType<A, S>` from a ``Rig`` / ``Transceiver``. |

### Reading in SwiftUI (`SwiftRex.SwiftUI` — Apple platforms)

| Type | Kind | Role | Hold it as |
|---|---|---|---|
| `ViewStore<Action, State>` | struct | **the receiver** — the only readable store. `viewStore.state` is the root position; `dispatch`, `focus`, bindings, `transpose` and `read(derived:)` live here. Carries its own Combine subscription so a plain `let` works under every strategy. | `let` |
| `GranularTracking<Value>` | struct | a *position* in the state (`viewStore.state.player`) — reads through it are granular; hand it to a subview that only reads. | `let` |
| `@OwnedStore` | property wrapper | **the owner** in a view or `App`: follows any ``StoreType`` once per view identity (lazy, like `@StateObject`) and hands out a `ViewStore`. | `@OwnedStore var viewStore = appStore` |
| `ProjectionKeeper` | view | **the owner** inline in a body (a router, a sheet, a list row): builds the view store once per identity and passes it to its content. | — |
| `IndivisibleTracking` | protocol | marks types read *whole* (`String`, numbers, `Bool`, `Date`, `UUID`, `URL`, `Data`, optionals and arrays of those; your own via an empty extension). Everything else is read as a `GranularTracking` position. | — |
| `ViewStrategy` | enum | how an owner signals SwiftUI: `.automatic` (default), `.observation`, `.combine`. | — |

`viewStore.focus(.action(\.player).state(\.player))` gives a child a `ViewStore` of a key-path slice: it reads through the parent's snapshot (no new subscription, no owner needed) and dispatches through its own lane.

### Macros (`SwiftRex.Architecture` / `SwiftRex.SwiftUI`)

| Macro | Generates |
|---|---|
| `@Feature(strategy: = .automatic)` | a feature's `view(store:environment:)` that **owns** its view store (a `ProjectionKeeper`, buffered before the map when `State: Equatable`) and hands `Content` a `ViewStore`; plus optics, `initialState(with:)` and the `Feature` conformance. |
| `@BoundTo(Feature.self)` | `let viewStore: ViewStore<Feature.ViewAction, Feature.ViewState>` in the view — the receiver. Never takes a strategy. |

### Following outside SwiftUI

| API | Module | Gives you |
|---|---|---|
| `store.stateStream.observe { }` | `SwiftRex` | callbacks, current state first; retain the ``UISubscriptionToken``. |
| `for await state in store.stateStream` | `SwiftRex` | an `AsyncSequence` that skips states a slow loop didn't get to. |
| `store.stateStream` as a `Publisher` | `SwiftRex.Combine` | the stream **is** a Combine `Publisher`. |
| `store.stateStream` as an `ObservableType` | `SwiftRex.RxSwift` | the stream **is** an RxSwift `ObservableType` (`asObservable()` for free). |
| `store.stateStream.producer` | `SwiftRex.ReactiveSwift` | the stream is a `SignalProducerConvertible`. |
| `store.stateStream.asPublisher` | `SwiftRex.ReactiveConcurrency` | a ReactiveConcurrency `Publisher`. |

Every bridge delivers the current state first, then each new state, on the main actor.

### Removed — and what replaced them

| Was | Now |
|---|---|
| `store.state` on any store | follow `store.stateStream`; views read `viewStore.state` (`TestStore.state` stays) |
| `observe(willChange:didChange:)` | `stateStream.observe { state in … }` |
| `ObservableStore` / `ObservableStoreType` | `ViewStore` (concrete) — its engine is internal |
| `StateNode<Store, Value>` | `GranularTracking<Value>` |
| `ObservableLeaf` | `IndivisibleTracking` |
| `node.unwrapped()` | `position.transpose()` |
| `presence` / `item` / `presenting` / `presentingItem` | `binding(.state(…).action(…))`, typed by the SwiftUI parameter; `.sheet(item:)` takes a `Binding<Presentation<T>>` |
| `ScopedStore` / `node.scoped(action:)` | `viewStore.focus(.action(\.x).state(\.x))` — a `ViewStore` |
| `@ObservedStore` | `@OwnedStore` |
| `ObservableStoreHost` / `observable()` | `ProjectionKeeper { store } content: { viewStore in … }` |
| `peek` in action closures | dispatch the intent; the reducer reads the state |
| `store.publisher` / `store.stream` | `store.stateStream` (a `Publisher` / an `AsyncSequence`) |
| core `transpose()` on ``StoreType`` | `viewStore.transpose()` → `ViewStore<T>?` in a body; elsewhere presence is state (`stateStream.map { $0.child != nil }.removeDuplicates()`) |
| `TrackedViewStore` + `@Tracked` | nothing to write — reads are granular at any depth |
| `ObservableObjectStore` / `asObservableObject()` | `@OwnedStore(.combine) var viewStore = appStore` |
| `ViewStrategy.observationSimple` / `.observationGranular` / `.combineObservable` | `.automatic` / `.observation` / `.combine` |
| `@BoundTo(X.self, strategy: …)` | `@BoundTo(X.self)` |

## Common, Observation-only, Combine-only

Every SwiftUI type above is **common** — the same code under both mechanisms. Only the *signal* the owner picks differs:

| | Common to both | Observation only | Combine only |
|---|---|---|---|
| Types | `ViewStore`, `GranularTracking`, `@OwnedStore`, `ProjectionKeeper`, `IndivisibleTracking`, the bindings | the view store's Observation registrar (iOS 17 / macOS 14 / tvOS 17 / watchOS 10) | its `objectWillChange` |
| What's tracked | the key paths each view read, compared with `==` | — | — |
| Signal | — | the Observation registrar, **per changed path** | one `objectWillChange` when **any** read path changed |
| Who redraws | — | only the views that read a changed path | every view holding the `ViewStore` or a `GranularTracking` of it |
| Selected by | `ViewStrategy` at the owner | `.observation`, or `.automatic` on iOS 17+ | `.combine`, or `.automatic` below iOS 17 |

Nothing in user code is availability-gated: `.automatic` decides at runtime. Receivers never know which signal is in use.

## Worked example: who redraws?

```swift
struct Ble: Sendable, Equatable { var bli: Int; var blo: String }
struct Bla: Sendable, Equatable { var ble: Ble }
struct AppState: Sendable, Equatable { var bla: Bla; var other: Int }

struct ViewA: View {                                     // reads a leaf deep down
    let viewStore: ViewStore<AppAction, AppState>
    var body: some View { Text("\(viewStore.state.bla.ble.bli)") }        // depends on \.bla.ble.bli
}
struct ViewB: View {                                     // reads a position's whole value
    let viewStore: ViewStore<AppAction, AppState>
    var body: some View { Text("\(viewStore.state.bla.ble.value.blo)") }  // depends on \.bla.ble (a Ble, compared with ==)
}
struct ViewC: View {                                     // receives a position, reads a leaf in it
    let ble: GranularTracking<Ble>                                        // passed as `viewStore.state.bla.ble`
    var body: some View { Text(ble.blo) }                                 // depends on \.bla.ble.blo
}
struct ViewD: View {                                     // reads the whole state
    let viewStore: ViewStore<AppAction, AppState>
    var body: some View { Text("\(viewStore.state.value.other)") }        // depends on \.self — everything
}
```

`viewStore.state.bla` and `viewStore.state.bla.ble` are **positions** — `Bla`/`Ble` aren't `IndivisibleTracking` — so merely reaching through them records nothing; only the final read does. `bli` and `blo` are `Int`/`String` leaves.

| Change | Observation redraws | Combine redraws |
|---|---|---|
| `bla.ble.bli` 1 → 2 | **A** (its path changed), **B** (`ble` changed as a whole), **D** (everything changed). **Not C** — `blo` didn't change. | A read path changed → one `objectWillChange` → **A, B, C, D** (every view holding the view store or a position of it). |
| `bla.ble.blo` "x" → "y" | **B, C, D**. Not A. | **A, B, C, D**. |
| `other` 0 → 1 | **D** only. | D read the whole state, so it changed → **A, B, C, D**. Without ViewD: **nothing** — no read path changed. |
| `bla.ble.bli` 1 → 1 (same value) | **nothing** — `==` says unchanged. | **nothing**. |
| `Ble` not `Equatable`, `other` changes | D, and **B** (a non-`Equatable` value can't be compared, so it always counts as changed). | as above. |

Takeaways:

- **Under Observation, depth pays off directly**: a view redraws only for the exact paths it read. Pass positions (`viewStore.state.bla.ble`) to subviews rather than values, and keep reads as deep as the view needs.
- **Under Combine, the signal is all-or-nothing per view store** — but it's still *gated*: no view read anything that changed, no signal. Avoid coarse reads (`viewStore.state.value`) there especially: one of them turns every change into a full redraw.
- **`==` everywhere**: make view-facing types `Equatable`. A non-`Equatable` value read whole invalidates on every change that reaches the view store.
- **Cost of a change** grows with what changed, not with how much is watched: dependencies form a tree along the paths (`\.bla` → `\.bla.ble` → `\.bla.ble.bli`), and the diff skips a whole subtree when its root compares equal — one `==` on an unchanged `bla` skips everything beneath it. A list's rows (`each`) sit under the list, so an unchanged list costs one comparison however many rows are on screen.

## See Also

- <doc:ObservingInSwiftUI>
- <doc:Features>
- ``Store``
- ``StoreProjection``
- ``StoreBuffer``
- ``StateStream``
