# ``SwiftRex/StoreProjection``

A stateless lens onto a Store — presents a narrower action and state to a feature or view.

## Overview

`StoreProjection<Action, State>` is a `struct` that holds no state of its own: it maps a global store's action and state to a local slice — its ``stateStream`` is the underlying stream, mapped for each observer. It conforms to ``StoreType``, so a feature can be handed a `StoreProjection` and never needs to know where its slice lives in the global state.

```swift
let counter = appStore.projection(.action(\.counter).state(\.counter))
// StoreProjection<CounterAction, CounterState>
```

A declared scope works the same — the one a feature already uses to lift its behavior (`static let counter = ScopeOf<AppFeature>.action(\.counter).state(\.counter).environment(…)`): `appStore.projection(AppScopes.counter)`. Reach for the closure form, `projection(action:state:)`, only for a derived view state no key path expresses (`state: CounterViewState.init`); ``StoreType/projection(environment:action:state:)`` takes `Reader`s when the maps need the environment.

A single collection element is a separate stage, ``StoreCollectionFocus`` — see the per-element shape below.

`StoreProjection` does **no** caching or deduplication — the map runs once per upstream change for each observer. To skip redundant work, put a ``StoreBuffer`` (``StoreType/buffer()``) **before** a costly map: `store.buffer().projection(…)` runs the map only when its input changed. A buffer *after* the map (`projection(…).buffer()`) still runs the map on every change and only suppresses identical results — for SwiftUI the view store already does that per key path.

## Three view-side read shapes

A view reads its slice through a ``Relay/Scope`` — the same value that wires a child on the behavior side. A projection needs the action lane to **embed** and the state lane to **read**; the environment lane is ignored. There are three shapes, distinguished by what the state lane focuses:

**Whole collection** — the base ``StoreType/projection(_:)-(Relay.Scope<Self.Action,A,Self.State,S,Never,Relay.Absurd<Never>>)`` over a state lane that reads the entire collection. The projected state is the collection itself; a list view iterates it and projects each row separately.

```swift
let rows = store.projection(.action(\.bulk).state(\.rows))
// StoreProjection<BulkAction, [Row]>
```

**Per-element** — ``StoreType/projection(_:element:)-(Relay.Scope<Self.Action,A,Self.State,S,Never,Relay.Absurd<Never>>,_)`` addresses one element by `id`, through a ``Relay/Scope`` whose action lane is an ``Relay/ActionAxis/Element`` and whose state lane is a ``Relay/StateAxis/Keyed``. The `Keyed` lane abstracts the locator, so one call covers every collection shape — `Identifiable` id (`.state(\.rows)`), custom id (`.state(\.rows, id: \.slug)`), position (`.state(indexed: \.rows)`) or dictionary key (`.state(dictionary: \.byKey)`). It returns a ``StoreCollectionFocus``, not a `StoreProjection`: each observer keeps a hint of where it last found its element, so following it costs O(distance moved). A store can't be absent, so its state is `Element?`, `nil` while the element isn't there; dispatched sub-actions are re-embedded as an ``ElementAction`` addressed at `id`.

```swift
let row = store.projection(.action(\.row).state(\.rows), element: id)
// StoreCollectionFocus<RowAction, Row> — state Row?
```

**Optional child** — the base ``StoreType/projection(_:)-(Relay.Scope<Self.Action,A,Self.State,S,Never,Relay.Absurd<Never>>)`` again, this time over a state lane that reads an optional slice. The projected state is `Child?`, present or absent as the slice is `.some` or `.none`.

```swift
let child = store.projection(.action(AppAction.prism.child).state(\.child))
// StoreProjection<ChildAction, Child?>
```

The last two shapes both hand back a store of an *optional*. A child screen wants a store of the *unwrapped* value — a ``StoreOptionalFocus``, which is what `traverse` gives you in SwiftUI.

## Optional children — presence is state

A store of an optional slice (state `T?`) is what a projection gives for an optional child, and what a ``StoreCollectionFocus`` gives for an element. Deciding *whether* to show the child is a read of the current value, and a plain store can't be read — but it can be followed, and presence is just part of the state it delivers. Outside SwiftUI (UIKit, AppKit, a renderer on another platform), follow the presence edge and present or dismiss on it; the child screen gets a ``StoreOptionalFocus`` over a projection of the slot — `StoreOptionalFocus(store.projection(.action(\.editor).state(\.editor)), present: editor)`:

```swift
token = store.stateStream
    .map { $0.editor != nil }
    .removeDuplicates()
    .observe { isShown in isShown ? presentEditor() : dismissEditor() }
```

### In SwiftUI — `traverse`

A `ViewStore` (`SwiftRex.SwiftUI`) can read, so it decides the nesting directly: `traverse(scope)` reads the presence edge from its snapshot — the body re-runs exactly when the child appears or goes away — and returns a pure ``StoreOptionalFocus`` of the unwrapped value, holding its last value while the child animates away. Hand it to the child view, which keeps its own view store:

| State | Form |
|---|---|
| `T?` reached by a key path | `viewStore.traverse(.action(\.child).state(\.child))` |
| `Presentation` — alive through `presented` **and** `dismissing(last:)`, `nil` once `dismissed` (flicker-free) | `viewStore.traverse(.action(\.editor.child).state(\.editor))` |
| `T?` reached by a closure lane (an affine preview, the top of a stack) | `viewStore.traverse(action: { .child($0) }, state: { $0.path.last?.child })` |
| one element of a collection | `viewStore.traverse(.action(\.row).state(\.rows), element: id)` |

```swift
if let editor = viewStore.traverse(.action(\.editor.child).state(\.editor)) {
    EditorView(store: editor) // keeps _viewStore = OwnedStore(wrappedValue: store.viewStore()); or EditorFeature.view(store: editor, …)
}
```

For a `ForEach` over rows that dispatch or bind, `viewStore.each(.action(\.row).state(\.rows))` gives one ``IdentifiedStore`` per element, and the list depends on the ids only.

`transpose()` is the `sequence`-shaped swap of a view store's own optional (`T?` or `Presentation<T>` state); `traverse(scope)` is map then `transpose` — the names follow `sequence`/`traverse`. Neither is a lawful `Traversable` instance: a ``Store`` holds a value over time, and the current value decides the nesting.

## Topics

### Following & Dispatching

- ``stateStream``
- ``dispatch(_:source:)``

### Projecting

- ``StoreType/projection(_:)-(Relay.Scope<Self.Action,A,Self.State,S,Never,Relay.Absurd<Never>>)``
- ``StoreType/projection(_:)-(Relay.Scope<Self.Action,A,Self.State,S,GE,E>)``
- ``StoreType/projection(_:element:)-(Relay.Scope<Self.Action,A,Self.State,S,Never,Relay.Absurd<Never>>,_)``
- ``StoreType/projection(_:element:)-(Relay.Scope<Self.Action,A,Self.State,S,GE,E>,_)``
- ``StoreType/projection(environment:action:state:)``

## See Also

- ``Store``
- ``StoreBuffer``
- ``StoreType``
- ``StoreCollectionFocus``
- ``StoreOptionalFocus``
- ``ElementAction``
