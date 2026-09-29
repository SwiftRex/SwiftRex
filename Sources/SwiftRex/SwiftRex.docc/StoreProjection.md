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

`StoreProjection` does **no** caching or deduplication — the underlying ``Store`` always notifies, and reading `state` runs the map every time. To skip redundant work, put a ``StoreBuffer`` (``StoreType/buffer()``) **before** the map: `store.buffer().projection(…)` runs the map only when its input changed. A buffer *after* the map (`projection(…).buffer()`) still runs the map on every change and only suppresses identical results — for SwiftUI the observed store already does that per key path.

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

The last two shapes both hand back a store of an *optional*. A child screen wants a store of the *unwrapped* value — that is what ``StoreType/transpose()`` is for.

## Transpose — `Store<T?>` into `Store<T>?`

A projection onto an optional slice is a *store of an optional* (`StoreProjection<A, T?>`); a child screen wants a *store of the unwrapped value*, and, when absent, no store at all. ``StoreType/transpose()`` swaps the two type constructors' nesting: `Store<Optional<T>>` becomes `Optional<Store<T>>` — `.some(store)` when the value is present, `nil` when absent.

It is named **transpose**, not `sequence`/`traverse`, because a ``Store`` is not `Traversable` — there is no lawful traversal here. The swap works because a store is *peekable*: the current value decides the nesting at call time. The unwrapped store reads the live value, falling back to the value captured at `transpose()`-time on the transient frame where the source reads `nil`, so it never force-unwraps and holds the last value steady across a dismissal.

On a plain store — a test, a service, anything outside SwiftUI — compose the per-element (or optional) projection with `transpose()`:

```swift
if let rowStore = store.projection(.action(AppAction.prism.row).state(\.rows), element: id).transpose() {
    rowStore.dispatch(.rename("New"))
}
```

Because the fallback value is retained for the transient absent frame, the unwrapped store — and its view — survive the render on which the element is removed, rather than crashing or blanking.

### In a SwiftUI body — transpose the observed store

This core overload decides presence by reading ``StoreType/state``. On an observed store inside a view body that is a read of the **whole** state, so the view would redraw on every change. `SwiftRex.SwiftUI` adds overloads on the observed store that depend on the **presence edge only**:

| State | Form |
|---|---|
| `T?` reached by a key path | `store.child.scoped(action: .action(\.child)).transpose()` |
| `T?` reached by a closure lane (an affine preview, the top of a stack) | `store.transpose(action: { .child($0) }, state: { $0.path.last?.child })` |
| ``Presentation`` — alive through `presented` **and** `dismissing(last:)`, `nil` once `dismissed` (flicker-free) | `store.editor.scoped(action: .action(\.editor)).transpose()` |

```swift
if let row = store.transpose(action: { AppAction.row(id, $0) }, state: { $0.rows.first { $0.id == id } }) {
    Row.view(store: row, environment: world.rowEnv)
}
```

For whole lists, prefer `ForEach(store.each(\.rows)) { row in … row.scoped(action: …) }` — see <doc:ObservingInSwiftUI>.

## Topics

### Reading & Dispatching

- ``state``
- ``dispatch(_:source:)``

### Projecting & unwrapping

- ``StoreType/projection(_:)-(Relay.Scope<Self.Action,A,Self.State,S,Never,Relay.Absurd<Never>>)``
- ``StoreType/projection(_:)-(Relay.Scope<Self.Action,A,Self.State,S,GE,E>)``
- ``StoreType/projection(_:element:)-(Relay.Scope<Self.Action,A,Self.State,S,Never,Relay.Absurd<Never>>,_)``
- ``StoreType/projection(_:element:)-(Relay.Scope<Self.Action,A,Self.State,S,GE,E>,_)``
- ``StoreType/transpose()``

## See Also

- ``Store``
- ``StoreBuffer``
- ``StoreType``
- ``ElementAction``
