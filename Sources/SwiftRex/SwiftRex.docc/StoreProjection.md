# ``SwiftRex/StoreProjection``

A stateless lens onto a Store — presents a narrower action and state to a feature or view.

## Overview

`StoreProjection<Action, State>` is a `struct` that holds no state of its own: it maps a global store's action and state to a local slice, recomputing `state` on each read from its stored closures. It conforms to ``StoreType``, so a feature can be handed a `StoreProjection` and never needs to know where its slice lives in the global state.

```swift
let counter = appStore.projection(
    action: AppAction.counter,        // CounterAction → AppAction
    state: \.counterState             // AppState → CounterState
)
```

Focus a single collection element with the `projection(element:…)` (by `Identifiable` id or custom identifier) or `projection(key:…)` (dictionary) factories — actions are wrapped in an ``ElementAction``.

`StoreProjection` does **no** deduplication — the underlying ``Store`` always notifies. When you want to skip redundant view updates, wrap it in a ``StoreBuffer`` via ``StoreType/buffer()``.

## Topics

### Reading & Dispatching

- ``state``
- ``dispatch(_:source:)``

## See Also

- ``Store``
- ``StoreBuffer``
- ``StoreType``
- ``ElementAction``
