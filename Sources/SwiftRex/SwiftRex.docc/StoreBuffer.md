# ``SwiftRex/StoreBuffer``

A caching, deduplicating wrapper — propagates a state change only when the slice actually changed.

## Overview

`StoreBuffer<Action, State>` is a `@MainActor` `final class` that wraps any ``StoreType`` and adds **caching and deduplication**: it holds a `state` snapshot and notifies its observers only when the new value differs — by `Equatable`, or by a predicate you supply. The plain ``Store`` always notifies and copies nothing; `StoreBuffer` is where you opt into "skip the redundant work". In a SwiftUI pipeline its place is **before** a projection's map — `store.buffer().projection(…).observable()` runs the map only when its input changed; after the map, `observable()` already passes on only what changed (per dependency), so a second buffer there is redundant. `@Feature` builds exactly that chain when the feature's `State` is `Equatable`.

```swift
let counter = appStore
    .projection(action: AppAction.counter, state: \.counter)       // the feature's slice
    .buffer()                                                      // dedup on it — Counter.State: Equatable
    .projection(action: { $0 }, state: CounterView.init)           // the (possibly wide) view map
```

Which side of a projection it sits on decides what it saves:

- **Before a map** — dedups on the map's *input*, so the map doesn't run for changes elsewhere in the app. This stops redundant **recomputation**, the expensive half for a wide view state.
- **After a map** — dedups on the map's *output*: the map still runs on every upstream change, but observers aren't told when the result is identical. This stops redundant **invalidation** only.

For SwiftUI, the observable store a view reads (`@ObservedStore`, or `@Feature`'s generated view) already does the "after" job per key path, so the pipeline is **``Store`` → ``StoreProjection`` (slice) → `StoreBuffer` → ``StoreProjection`` (view map) → observed**.

## Topics

### Creating a Buffer

- ``StoreType/buffer()``

### Reading & Dispatching

- ``state``
- ``dispatch(_:source:)``

## See Also

- ``Store``
- ``StoreProjection``
- ``StoreType``
