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

The view flow composes the per-element (or optional) projection with `transpose()` and `map`:

```swift
if let rowStore = store.projection(.action(AppAction.prism.row).state(\.rows), element: id).transpose() {
    Row.view(store: rowStore, environment: world.rowEnv)
}
// or point-free:
store.projection(scope, element: id)
    .transpose()
    .map { Row.view(store: $0, environment: world.rowEnv) }   // View?
```

Because the fallback value is retained for the transient absent frame, the unwrapped store — and its view — survive the render on which the element is removed, rather than crashing or blanking. SwiftRexSwiftUI adds a ``Presentation`` overload (`transpose()` over `Presentation<Wrapped>`) that turns that retention into a modeled `dismissing(last:)` stage: it presents through **both** `presented` and `dismissing`, and reads `nil` only once `dismissed`, so a presented child stays alive and steady while SwiftUI animates the sheet out — flicker-free.

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
