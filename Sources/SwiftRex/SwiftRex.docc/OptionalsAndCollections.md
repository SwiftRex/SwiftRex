# Optionals and Collections

Lift one unit over *variable* state — a 0-or-1 optional child or a 0-or-n collection — and drive the
view side from the same wiring.

## Overview

Most lifting re-indexes a child whose state is *always there* (<doc:Lifting>). But state is often
**variable**: a detail screen that exists only while shown, a list whose rows come and go. SwiftRex models
this with three dedicated hosts that all take the **same** ``Relay/Scope`` you already know — the
element/optional addressing rides in the lanes, so the spelling stays a naked leading-dot chain and the
compiler only offers each host the lanes it can honour:

| Host | Shape | The unit runs… |
|---|---|---|
| `liftOptional` | 0-or-1 | on the **unwrapped** value while `.some`; a complete no-op while `nil` |
| ``Behavior/liftCollection(_:)`` | 0-or-n, route one | on the one **unwrapped** element an action addresses |
| ``Behavior/liftEach(_:)`` | 0-or-n, broadcast | on **every** present element |

In every case the lifted unit sees the **unwrapped** focus — never `Element?` — and per-element effect
scheduling and `supervise` channels are scoped to each element automatically, so one row's
`.debounce(id:)` never collides with another's. All three exist on `Behavior`, `Reducer`, and `Middleware`
(a `Reducer` has no effects to scope; a `Middleware` only reads the focus).

## liftOptional — the 0-or-1 host

`liftOptional` is the host whose action and environment axes must be **absent** and whose state axis is an
affine write — the compiler enforces "everything absent but state". It runs the unit focused on the
unwrapped value while present, and is a **complete** no-op while `nil` (no mutation, no effect, no
supervise — stricter than a plain affine state lift):

```swift
dayBehavior.liftOptional(.state(\AppState.currentDay))   // currentDay: DayDetail.State?
```

The bare key-path form is kept as sugar:

```swift
dayBehavior.liftOptional(\AppState.currentDay)
```

This is exactly the shape presentation uses — a child module whose state exists only while it is shown.
(There is no `Reducer.liftOptional`/projection form: a `Reducer` folds into the optional via
``Reducer/liftCollection(_:)-(Relay.Scope<A.Global,A,S.Global,S,Never,Relay.Absurd<Never>>)``-style optics, and a store can never be *absent* — see the view side below.)

## liftCollection and liftEach — the 0-or-n hosts

``Behavior/liftCollection(_:)`` routes an addressed action to **one** element; ``Behavior/liftEach(_:)``
broadcasts to **every** element. Both take the same naked leading-dot scope inline (no ``ScopeOf`` entry
needed — the host pins the globals):

```swift
// route one: the action lane carries the element id via an ElementAction prism
rowBehavior.liftCollection(.action(AppAction.prism.row).state(\AppState.rows).environment(\.rowEnv))

// broadcast: the action lane bridges a plain inbound case and the id-addressed outbound case
rowBehavior.liftEach(.action(broadcast: AppAction.prism.tickAll, into: AppAction.prism.row).state(\AppState.rows).environment(\.rowEnv))

// the view dispatches an addressed action; the wiring finds and unwraps the element:
store.dispatch(.row(ElementAction(row.id, action: .toggleDone)))
```

The global action carries an ``ElementAction`` for the collection case:

```swift
enum AppAction {
    case row(ElementAction<Int, RowAction>)   // route-one / broadcast target
    case tickAll(RowAction)                    // a plain "do X to all" case, for liftEach
}
```

### Locating an element

The `.state(…)` lane picks how an element is found — each spelling coexists with the base state lanes,
resolved by the host:

```swift
.state(\AppState.rows)                 // by Identifiable id  (Row: Identifiable)
.state(\AppState.rows, id: \.slug)     // by a custom Hashable key path (Row need not be Identifiable)
.state(indexed: \AppState.rows)        // by position (Collection.Index)
.state(dictionary: \AppState.configs)  // by dictionary Key ([Key: Value])
```

### The input zoo — including macro-free

The route-one action lane accepts a prism, a `\.case` key path, or a raw `(preview, review)` closure pair,
so nobody is forced into `@Prisms` or a hand-written prism:

```swift
.action(AppAction.prism.row)                                    // a Prism into the ElementAction case
.action(\.row)                                                  // a case key path
.action(                                                        // macro-free: raw closures
    preview: { g in if case let .row(ea) = g { (id: ea.id, action: ea.action) } else { nil } },
    review:  { id, a in AppAction.row(ElementAction(id, action: a)) }
)
```

## The view side — reading optionals and collections

A view reads through a **view store** (a `ViewStore`, handed down by `@Feature` or `@OwnedStore` — see
<doc:ObservingInSwiftUI>), and variable state has three read shapes there:

```swift
// whole collection — one position per row; the list depends on the ids, each row on its own element
ForEach(viewStore.state.each(\.rows)) { row in RowView(row: row) }

// an optional child — its presence (a read, on the view store), then a pure stage the child's view owns
if let child = viewStore.transpose(.action(\.child).state(\.child)) { ChildFeature.view(store: child, environment: world.childEnv) }

// one element — by id, by position or by key — through the same collection scope a projection takes
if let cell = viewStore.transpose(.action(\.row).state(\.rows), element: id) { ProjectionKeeper { cell.viewStore() } content: { … } }
```

Deriving from any store gives a **pure stage** — something that follows a stream and keeps nothing a parent holds.
To observe one, own it: a feature's view does, `ProjectionKeeper` in a body, `@OwnedStore` as a property.

```swift
let list: StoreProjection<BulkAction, [Row]> = store.projection(.action(AppAction.prism.bulk).state(\.rows))
let cell: StoreCollectionFocus<RowAction, Row> = store.projection(.action(AppAction.prism.row).state(\.rows), element: id)
let child: StoreProjection<ChildAction, Child?> = store.projection(.action(AppAction.prism.child).state(\.child))
```

The same `.state(\.rows)` resolves to a **reading** lane for a projection (which reads) and to a **keyed**
lane for `liftCollection` (which writes per element) — the host decides, with no ambiguity.

### transpose — a store of optional becomes an optional store

To hand a child `Feature` a store of the **unwrapped** value, invert the two type constructors with
`transpose`: `Store<Optional<T>>` becomes `Optional<Store<T>>` — the store analogue of transposing
`Optional<[T]>` ⇄ `[Optional<T>]`.

Deciding *whether* the value is there is a read, so `transpose` lives on the `ViewStore` and the calling view
depends on the **presence edge only**. What it returns is a pure ``StoreOptionalFocus``: a store of the unwrapped value that
holds its last present value while the child animates away. Own it where the child is built.

```swift
// in a view body:
viewStore.transpose(.action(\.child).state(\.child))                 // StoreOptionalFocus<ChildAction, Child>?
    .map { ChildFeature.view(store: $0, environment: world.childEnv) }  // View? — the feature's view owns it

// a lane no key path expresses:
viewStore.transpose(action: { AppAction.row(id, $0) }, state: { $0.rows.first { $0.id == id } })
```

Outside SwiftUI, presence is plain state: follow `store.stateStream.map { $0.child != nil }.removeDuplicates()`,
and on `true` build `StoreOptionalFocus(store.projection(…), present: value)` for the child screen.

> It is deliberately **not** called `sequence`: a `Store` is not `Traversable`, so the swap claims no
> traversal law. It works because a view store knows the current value, which decides the nesting at call
> time. Once the source reads `nil`, the unwrapped store holds the last present value, so it never
> force-unwraps and keeps a dismissing screen steady.

### Presentation — the flicker-free child

For an animated modal, prefer ``Presentation`` (`presented` / `dismissing(last:)` / `dismissed`) over a
bare `T?`. Its `transpose` form keeps the child store live through **both** `presented` and `dismissing`, going
`nil` only at `dismissed` — so the sheet renders its last value steady as SwiftUI animates it out, with no flicker:

```swift
.sheet(item: viewStore.binding(.state(\.editor).action(\.editor))) { _ in
    if let editor = viewStore.transpose(.action(\.editor.child).state(\.editor)) {
        EditorFeature.view(store: editor, environment: world.editorEnv)
    }
}
```

### One element of a collection

``StoreCollectionFocus`` is a pure stage for one element: `store.projection(scope, element: id)` — by `id`, custom id
`.state(\.rows, id: \.slug)`, position `.state(indexed:)` or key `.state(dictionary:)` — with the `ElementAction`
envelope, and an optional element because it can go away. In a view, `viewStore.transpose(scope, element: id)` reads
the element's presence and returns the row's store to own:

```swift
ForEach(viewStore.state.each(\.rows)) { row in
    if let rowStore = viewStore.transpose(.action(\.row).state(\.rows), element: row.id) {
        ProjectionKeeper(id: row.id) { rowStore.viewStore() } content: { RowView(viewStore: $0) }   // or RowFeature.view(store:…)
    }
}
```

Each row owns its own view store: it redraws only for its own element, is built once per id, and survives reorders.
The list's body depends on the ids (`each`) and each row's presence, never on a row's contents.

Finding the element: by position and by key it's O(1). By **id** each row's stage keeps a hint — where it last found
its element — and searches outward from it, so an element that moved by `k` costs `k` steps: O(1) for an insert or
remove, O(k) for a block of `k`, O(n) per row only after a shuffle, sort or reverse. The hint belongs to that row's
subscription; nothing is cached in the list. Measured with 1,000 owned rows (release): one row change ~7 ms, an insert
at the top 9 ms, a block of 10 at the top 20 ms, a full reverse ~320 ms. A `List` builds only its visible rows, so a
real screen pays for those alone.

By position follows the *position*: after a removal the same index holds another element. Prefer ids unless the list
never changes shape.

## Two-way bindings

A store-backed `Binding` reads state and *dispatches* on write (the reducer stays the only writer). Bindings
live on the view store. It takes
the same axis pair as every host — a `.state(…)` read and a `.action(…)` embed of the same value type —
so the slots can't be crossed and each offers only its own strategies (`\.case` / prism / `review:` /
`preview:` for actions, key path / closure / lens for state):

```swift
// action case:
TextField("Name", text: viewStore.binding(.state(\.name).action(\.setName)))
// or a transform, wrapping the closure in .action(review:):
TextField("Name", text: viewStore.binding(.state(\.name).action(review: { ViewAction.setName($0) })))

// a field of a collection element — the row's own view store, then bind:
struct RowView: View {
    let viewStore: ViewStore<RowAction, Row>
    var body: some View { TextField("Name", text: viewStore.binding(.state(\.name).action(\.setName))) }
}
```

## See Also

- <doc:Lifting>
- <doc:Navigation>
- ``Relay/Scope``
- ``ElementAction``
- ``StoreProjection``
- ``Presentation``
