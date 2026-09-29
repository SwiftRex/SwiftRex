# Stores at a Glance

Every type that behaves like a store, which module it lives in, what it's for — and exactly which views redraw when state changes, under Observation and under Combine.

## Overview

SwiftRex has one store that *runs* the app and several that *look like* it: they take actions, expose state, and can be observed. They differ in one question each — does it run the behavior? does it keep a copy of the state? can SwiftUI observe it? This page is the map; each row links to the type or article that goes deep.

> Tip: With `@Feature` you only ever *write* two of these: the ``Store`` (once, at launch) and the injected `viewStore` (a `ViewStore`). Everything else is built for you. See <doc:Features>.

## The index

### The contract

| Type | Kind | Module | What it is |
|---|---|---|---|
| ``StoreType`` | protocol | `SwiftRex` | Anything with `state`, `dispatch(_:source:)` and `observe(willChange:didChange:)`. Every row below conforms. |
| `ObservableStoreType` | protocol | `SwiftRex.SwiftUI` | A ``StoreType`` **SwiftUI can observe**: reads register per key path. The binding / presentation helpers (`binding`, `presence`, `item`, `presenting`, `transpose`, `hasScene`) exist only here. |

### Running and shaping state (core — every platform)

| Type | Kind | Keeps a state copy? | SwiftUI-observable? | Use it to |
|---|---|---|---|---|
| ``Store`` | class | owns *the* state | no | run the app: reducers, effects, the one source of truth. Build it once, at launch. |
| ``StoreProjection`` | struct | no — recomputes the map on every read | no | narrow action/state types (`store.projection(action:state:)`, or through a ``Relay/Scope``). |
| ``StoreBuffer`` | class | yes | no | skip redundant work: passes a change on only when `!=`. Put it **before** a costly map. |
| `TestStore` | class | owns a test state | no | exhaustive tests (`SwiftRex.Testing`). |
| ``StoreOf`` / ``StoreTypeOf`` | type aliases | — | — | spell `Store<A, S, E>` / `any StoreType<A, S>` from a ``Rig`` / ``Transceiver``. |

### Observing in SwiftUI (`SwiftRex.SwiftUI` — Apple platforms)

| Type | Kind | Role | Hold it as |
|---|---|---|---|
| `ObservableStore` | class | the observed store: one state snapshot + the record of what each view read + the signal (Observation or Combine). You rarely name it. | — (built by an owner) |
| `ViewStore<Action, State>` | struct | **the receiver** — what views hold. A reference to an `ObservableStore`; carries its own Combine subscription so a plain `let` works under every strategy. | `let` |
| `StateNode<Store, Value>` | struct | a *position* in the state (`store.player`) — reads through it are granular; hand it to a subview that only reads. | `let` |
| `ScopedStore` | struct | a key-path slice with its own action lane (`store.player.scoped(action: …)`) — for a subview that also dispatches or binds. Shares the root's snapshot; no new subscription. | `let` |
| `@ObservedStore` | property wrapper | **the owner** in a view or `App`: observes any ``StoreType`` once per view identity (lazy, like `@StateObject`) and hands out a `ViewStore`. | `@ObservedStore var store = appStore` |
| `ObservableStoreHost` | view | **the owner** inline in a body (a router, a sheet, a list row): builds the observed store once per identity and passes a `ViewStore` to its content. | — |
| `ObservableLeaf` | protocol | marks types read *whole* (`String`, numbers, `Bool`, `Date`, `UUID`, `URL`, `Data`, optionals and arrays of those; your own via an empty extension). Everything else is read as a `StateNode`. | — |
| `ViewStrategy` | enum | how an owner signals SwiftUI: `.automatic` (default), `.observation`, `.combine`. | — |

### Macros (`SwiftRex.Architecture` / `SwiftRex.SwiftUI`)

| Macro | Generates |
|---|---|
| `@Feature(strategy: = .automatic)` | a feature's `view(store:environment:)` that **owns** its store (an `ObservableStoreHost`, buffered before the map when `State: Equatable`) and hands `Content` a `ViewStore`; plus optics, `initialState(with:)` and the `Feature` conformance. |
| `@BoundTo(Feature.self)` | `let viewStore: ViewStore<Feature.ViewAction, Feature.ViewState>` in the view — the receiver. Never takes a strategy. |

### Observing outside SwiftUI

| API | Module | Gives you |
|---|---|---|
| ``StoreType/observe(willChange:didChange:)`` | `SwiftRex` | raw callbacks; retain the ``SubscriptionToken``. |
| `store.publisher` | `SwiftRex.Combine` / `SwiftRex.ReactiveConcurrency` | a `Publisher` of states (Combine / ReactiveConcurrency). |
| `store.stream` | `SwiftRex.SwiftConcurrency` | an `AsyncStream` of states. |

### Removed — and what replaced them

| Was | Now |
|---|---|
| `ViewStore` (the class holding a whole-state copy) | `ViewStore` the **receiver struct**, owned by `@ObservedStore` / `ObservableStoreHost` / `@Feature` |
| `TrackedViewStore` + `@Tracked` | nothing to write — reads are granular at any depth on the plain struct |
| `ObservableObjectStore` / `asObservableObject()` | `@ObservedStore(.combine) var store = appStore` |
| `ViewStrategy.observationSimple` / `.observationGranular` / `.combineObservable` | `.automatic` / `.observation` / `.combine` |
| `@BoundTo(X.self, strategy: …)` | `@BoundTo(X.self)` |
| bindings on a raw `Store` | bindings on the observed store (`ViewStore`) — the raw one never updated a view |

## Common, Observation-only, Combine-only

Every SwiftUI type above is **common** — the same code under both mechanisms. Only the *signal* the owner picks differs:

| | Common to both | Observation only | Combine only |
|---|---|---|---|
| Types | `ObservableStore`, `ViewStore`, `StateNode`, `ScopedStore`, `@ObservedStore`, `ObservableStoreHost`, `ObservableLeaf`, the bindings | the `Observable` conformance of `ObservableStore` (iOS 17 / macOS 14 / tvOS 17 / watchOS 10) | `objectWillChange` actually firing |
| What's tracked | the key paths each view read, compared with `==` | — | — |
| Signal | — | the Observation registrar, **per changed path** | one `objectWillChange` when **any** read path changed |
| Who redraws | — | only the views that read a changed path | every view holding a `ViewStore` / `StateNode` / `ScopedStore` of that store |
| Selected by | `ViewStrategy` at the owner | `.observation`, or `.automatic` on iOS 17+ | `.combine`, or `.automatic` below iOS 17 |

Nothing in user code is availability-gated: `.automatic` decides at runtime. Receivers never know which signal is in use.

## Worked example: who redraws?

```swift
struct Ble: Sendable, Equatable { var bli: Int; var blo: String }
struct Bla: Sendable, Equatable { var ble: Ble }
struct AppState: Sendable, Equatable { var bla: Bla; var other: Int }

struct ViewA: View {                                     // reads a leaf deep down
    let store: ViewStore<AppAction, AppState>
    var body: some View { Text("\(store.bla.ble.bli)") }        // depends on \.bla.ble.bli
}
struct ViewB: View {                                     // reads a node's whole value
    let store: ViewStore<AppAction, AppState>
    var body: some View { Text("\(store.bla.ble.value.blo)") }  // depends on \.bla.ble (a Ble, compared with ==)
}
struct ViewC: View {                                     // receives a node, reads a sibling leaf
    let ble: StateNode<ViewStore<AppAction, AppState>, Ble>     // passed as `store.bla.ble`
    var body: some View { Text(ble.blo) }                       // depends on \.bla.ble.blo
}
struct ViewD: View {                                     // reads the whole state
    let store: ViewStore<AppAction, AppState>
    var body: some View { Text("\(store.state.other)") }        // depends on \.self — everything
}
```

`store.bla` and `store.bla.ble` are **nodes** — `Bla`/`Ble` aren't `ObservableLeaf`s — so merely reaching through them records nothing; only the final read does. `bli` and `blo` are `Int`/`String` leaves.

| Change | Observation redraws | Combine redraws |
|---|---|---|
| `bla.ble.bli` 1 → 2 | **A** (its path changed), **B** (`ble` changed as a whole), **D** (everything changed). **Not C** — `blo` didn't change. | A read path changed → one `objectWillChange` → **A, B, C, D** (every view holding the store or a node of it). |
| `bla.ble.blo` "x" → "y" | **B, C, D**. Not A. | **A, B, C, D**. |
| `other` 0 → 1 | **D** only. | D read the whole state, so it changed → **A, B, C, D**. Without ViewD: **nothing** — no read path changed. |
| `bla.ble.bli` 1 → 1 (same value) | **nothing** — `==` says unchanged. | **nothing**. |
| `Ble` not `Equatable`, `other` changes | D, and **B** (a non-`Equatable` value can't be compared, so it always counts as changed). | as above. |

Takeaways:

- **Under Observation, depth pays off directly**: a view redraws only for the exact paths it read. Pass nodes (`store.bla.ble`) to subviews rather than values, and keep reads as deep as the view needs.
- **Under Combine, the signal is all-or-nothing per store** — but it's still *gated*: no view read anything that changed, no signal. Avoid coarse reads (`store.state`) there especially: one of them turns every change into a full redraw.
- **`==` everywhere**: make view-facing types `Equatable`. A non-`Equatable` value read whole invalidates on every change that reaches the store.
- **Cost of a change** grows with what changed, not with how much is watched: dependencies form a tree along the paths (`\.bla` → `\.bla.ble` → `\.bla.ble.bli`), and the diff skips a whole subtree when its root compares equal — one `==` on an unchanged `bla` skips everything beneath it. A list's rows (`each`) sit under the list, so an unchanged list costs one comparison however many rows are on screen.

## See Also

- <doc:ObservingInSwiftUI>
- <doc:Features>
- ``Store``
- ``StoreProjection``
- ``StoreBuffer``
