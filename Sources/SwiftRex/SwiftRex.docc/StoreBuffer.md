# ``SwiftRex/StoreBuffer``

A deduplicating wrapper — passes a state on only when it actually changed.

## Overview

`StoreBuffer<Action, State>` is a `@MainActor` `struct` that wraps any ``StoreType`` and adds **deduplication**: its ``stateStream`` passes a state on only when it differs from the previous one — by `Equatable`, or by a predicate you supply. It keeps no shared cache; each observer remembers its own previous value. The plain ``Store`` notifies after every mutation; `StoreBuffer` is where you opt into "skip the redundant work". In a SwiftUI pipeline its place is **before** a projection's map — `store.buffer().projection(…)` runs the map only when its input changed; after the map, the view store already signals only what changed (per dependency), so a second buffer there is redundant. `@Feature` builds exactly that chain when the feature's `State` is `Equatable`.

```swift
let counter = appStore
    .projection(.action(\.counter).state(\.counter)) // the feature's slice
    .buffer() // dedup on it — Counter.State: Equatable
    .projection(action: { $0 }, state: CounterViewState.init) // the (possibly wide) view map
```

Without `Equatable`, say what counts as a change: `buffer(hasChanged:)` takes `(previous, new) -> Bool` — `store.buffer { $0.items.count != $1.items.count }`.

Which side of a projection it sits on decides what it saves:

- **Before a map** — dedups on the map's *input*, so the map doesn't run for changes elsewhere in the app. This stops redundant **recomputation**, the expensive half for a wide view state.
- **After a map** — dedups on the map's *output*: the map still runs on every upstream change, but observers aren't told when the result is identical. This stops redundant **invalidation** only.

For SwiftUI, the view store a view reads (`@OwnedStore`, or `@Feature`'s generated view) already does the "after" job per key path, so the pipeline is **``Store`` → ``StoreProjection`` (slice) → `StoreBuffer` → ``StoreProjection`` (view map) → `ViewStore`**.

## Topics

### Creating a Buffer

- ``StoreType/buffer()``
- ``StoreType/buffer(hasChanged:)``

### Following & Dispatching

- ``stateStream``
- ``dispatch(_:source:)``

## See Also

- ``Store``
- ``StoreProjection``
- ``StoreType``
