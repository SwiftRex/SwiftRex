# ``SwiftRex/StoreBuffer``

A caching, deduplicating wrapper — propagates a state change only when the slice actually changed.

## Overview

`StoreBuffer<Action, State>` is a `@MainActor` `final class` that wraps any ``StoreType`` and adds **caching and deduplication**: it holds a `state` snapshot and notifies its observers only when the new value differs — by `Equatable`, or by a predicate you supply. The plain ``Store`` always notifies and copies nothing; `StoreBuffer` is where you opt into "skip the redundant render", which makes it the natural backing for SwiftUI observation.

```swift
let buffered = appStore
    .projection(action: AppAction.counter, state: \.counterView)  // narrow (StoreProjection)
    .buffer()                                                     // dedup — CounterView: Equatable
```

A typical pipeline is **``Store`` → ``StoreProjection`` (narrow) → `StoreBuffer` (dedup) → view**.

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
