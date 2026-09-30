# ``SwiftRex/StoreProjection``

A stateless lens onto a Store — presents a narrower action and state to a feature or view.

## Overview

`StoreProjection<Action, State>` is a `struct` that holds no state of its own: it maps a global store's action and state to a local slice — its ``stateStream`` is the underlying stream, mapped for each observer. It conforms to ``StoreType``, so a feature can be handed a `StoreProjection` and never needs to know where its slice lives in the global state.

```swift
let counter = appStore.projection(
    action: AppAction.counter,        // CounterAction → AppAction
    state: \.counterState             // AppState → CounterState
)
```

Focus a single collection element with the `projection(element:…)` (by `Identifiable` id or custom identifier) or `projection(key:…)` (dictionary) factories — actions are wrapped in an ``ElementAction``.

`StoreProjection` does **no** caching or deduplication — the map runs once per upstream change for each observer. To skip redundant work, put a ``StoreBuffer`` (``StoreType/buffer()``) **before** the map: `store.buffer().projection(…)` runs the map only when its input changed. A buffer *after* the map (`projection(…).buffer()`) still runs the map on every change and only suppresses identical results — for SwiftUI the view store already does that per key path.

## Three view-side read shapes

A view reads its slice through a ``Relay/Scope`` — the same value that wires a child on the behavior side. A projection needs the action lane to **embed** and the state lane to **read**; the environment lane is ignored. There are three shapes, distinguished by what the state lane focuses:

**Whole collection** — the base ``StoreType/projection(_:)-(Relay.Scope<Self.Action,A,Self.State,S,Never,Relay.Absurd<Never>>)`` over a state lane that reads the entire collection. The projected state is the collection itself; a list view iterates it and projects each row separately.

```swift
let rows = store.projection(.action(AppAction.prism.bulk).state(\.rows))
// StoreProjection<BulkAction, [Row]>
```

**Per-element** — ``StoreType/projection(_:element:)-(Relay.Scope<Self.Action,A,Self.State,S,Never,Relay.Absurd<Never>>,_)`` addresses one element by `id`, through a ``Relay/Scope`` whose action lane is an ``Relay/ActionAxis/Element`` and whose state lane is a ``Relay/StateAxis/Keyed``. The `Keyed` lane abstracts the locator, so one call covers every collection shape — `Identifiable` id, custom id, index position, or dictionary key. A store can't be absent, so the projected state is `Element?` (the view unwraps with `if let`); dispatched sub-actions are re-embedded addressed at `id`.

```swift
let row = store.projection(.action(AppAction.prism.row).state(\.rows), element: id)
// StoreProjection<RowAction, Row?>
```

**Optional child** — the base ``StoreType/projection(_:)-(Relay.Scope<Self.Action,A,Self.State,S,Never,Relay.Absurd<Never>>)`` again, this time over a state lane that reads an optional slice. The projected state is `Child?`, present or absent as the slice is `.some` or `.none`.

```swift
let child = store.projection(.action(AppAction.prism.child).state(\.child))
// StoreProjection<ChildAction, Child?>
```

The last two shapes both hand back a store of an *optional*. A child screen wants a store of the *unwrapped* value — that is what `transpose()` is for.

## Transpose — `Store<T?>` into `Store<T>?`

A store of an optional slice (`Store<A, T?>`) is not what a child screen wants: it wants a *store of the unwrapped value*, and, when absent, no store at all. `transpose()` swaps the two type constructors' nesting: `Store<Optional<T>>` becomes `Optional<Store<T>>` — `.some(store)` when the value is present, `nil` when absent.

Deciding which is a **read** of the current value, so `transpose` lives on the `ViewStore` (`SwiftRex.SwiftUI`) — the one store that can be read — and the reading view depends on the **presence edge only**:

| State | Form |
|---|---|
| `T?` reached by a key path | `viewStore.focus(.state(\.child), .action(\.child)).transpose()` |
| `T?` reached by a closure lane (an affine preview, the top of a stack, one element) | `viewStore.transpose(action: { .child($0) }, state: { $0.path.last?.child })` |
| ``Presentation`` — alive through `presented` **and** `dismissing(last:)`, `nil` once `dismissed` (flicker-free) | `viewStore.focus(.state(\.editor), .action(\.editor)).transpose()` |

```swift
if let row = viewStore.transpose(action: { AppAction.row(id, $0) }, state: { $0.rows.first { $0.id == id } }) {
    Row.view(store: row, environment: world.rowEnv)
}
```

The result is a `StoreProjection` of the unwrapped value that follows its own state. Once the source reads `nil`, it holds the last present value, so the child screen never force-unwraps and stays steady while SwiftUI animates it away.

It is named **transpose**, not `sequence`/`traverse`, because a ``Store`` is not `Traversable` — there is no lawful traversal here; the current value decides the nesting at call time.

## Topics

### Following & Dispatching

- ``stateStream``
- ``dispatch(_:source:)``

### Projecting & unwrapping

- ``StoreType/projection(_:)-(Relay.Scope<Self.Action,A,Self.State,S,Never,Relay.Absurd<Never>>)``
- ``StoreType/projection(_:)-(Relay.Scope<Self.Action,A,Self.State,S,GE,E>)``
- ``StoreType/projection(_:element:)-(Relay.Scope<Self.Action,A,Self.State,S,Never,Relay.Absurd<Never>>,_)``
- ``StoreType/projection(_:element:)-(Relay.Scope<Self.Action,A,Self.State,S,GE,E>,_)``

## See Also

- ``Store``
- ``StoreBuffer``
- ``StoreType``
- ``ElementAction``
