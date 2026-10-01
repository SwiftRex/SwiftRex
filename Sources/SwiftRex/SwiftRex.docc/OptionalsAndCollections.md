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
`.debounce(id:)` never collides with another's. `liftCollection` and `liftEach` exist on `Behavior`, `Reducer`, and
`Middleware` (a `Reducer` has no effects to scope; a `Middleware` only reads the focus); `liftOptional` on `Behavior`
and `Middleware`.

## liftOptional — the 0-or-1 host

`liftOptional` is the host whose action and environment axes must be **absent** and whose state axis is an
affine write — the compiler enforces "everything absent but state". It runs the unit focused on the
unwrapped value while present, and is a **complete** no-op while `nil` (no mutation, no effect, no
supervise — stricter than a plain affine state lift):

```swift
dayBehavior.liftOptional(.state(\AppState.currentDay)) // currentDay: DayDetail.State?
```

This is exactly the shape presentation uses — a child module whose state exists only while it is shown.
(There is no `Reducer.liftOptional`: a reducer has no effects or supervision to switch off, so its plain `lift`
over an optional state key path — `.action(\AppAction.day).state(\AppState.currentDay)`, an affine lane — already
runs only while the value is present. Nor is there a projection form: a store can never be *absent* — see the view
side below.)

## liftCollection and liftEach — the 0-or-n hosts

``Behavior/liftCollection(_:)`` routes an addressed action to **one** element; ``Behavior/liftEach(_:)``
broadcasts to **every** element. Both take the same naked leading-dot scope inline (no ``ScopeOf`` entry
needed — the host pins the globals):

```swift
// route one: the action lane carries the element id via an ElementAction prism
rowBehavior.liftCollection(.action(AppAction.prism.row).state(\AppState.rows).environment(\AppEnvironment.rowEnv))

// broadcast: the action lane bridges a plain inbound case and the id-addressed outbound case
rowBehavior.liftEach(.action(broadcast: \.tickAll, into: \.row).state(\AppState.rows).environment(\AppEnvironment.rowEnv))

// the view dispatches an addressed action; the wiring finds and unwraps the element:
store.dispatch(.row(ElementAction(row.id, action: .toggleDone)))
```

The global action carries an ``ElementAction`` for the collection case:

```swift
enum AppAction {
    case row(ElementAction<Int, RowAction>) // route-one / broadcast target
    case tickAll(RowAction) // a plain "do X to all" case, for liftEach
}
```

### Locating an element

The `.state(…)` lane picks how an element is found — each spelling coexists with the base state lanes,
resolved by the host:

```swift
.state(\AppState.rows) // by Identifiable id (Row: Identifiable)
.state(\AppState.rows, id: \.slug) // by a custom Hashable key path (Row need not be Identifiable)
.state(indexed: \AppState.rows) // by position (Collection.Index)
.state(dictionary: \AppState.configs) // by dictionary Key ([Key: Value])
```

### The input zoo — including macro-free

The route-one action lane accepts a prism, a `\.case` key path, or a raw `(preview, review)` closure pair,
so nobody is forced into `@Prisms` or a hand-written prism:

```swift
.action(AppAction.prism.row) // a Prism into the ElementAction case
.action(\.row) // a case key path
.action( // macro-free: raw closures
    preview: { g in if case let .row(ea) = g { (id: ea.id, action: ea.action) } else { nil } },
    review: { id, a in AppAction.row(ElementAction(id, action: a)) }
)
```

## The view side — reading optionals and collections

A view reads through a **view store** (a `ViewStore`, kept with `@OwnedStore` by the view that uses it — a
feature's generated view does it for you; see <doc:ObservingInSwiftUI>), and variable state has these shapes there:

```swift
// whole collection, display-only — one position per row; the list depends on the ids, each row on its own element
ForEach(viewStore.state.each(\.rows)) { row in RowLabel(row: row) }

// an optional child — its presence (a read, on the view store), then a pure stage the child's view owns
if let child = viewStore.traverse(.action(\.child).state(\.child)) { ChildFeature.view(store: child, environment: world.childEnv) }

// one element — by id, by position or by key — through the same collection scope a projection takes
if let cell = viewStore.traverse(.action(\.row).state(\.rows), element: id) { RowView(store: cell) }

// every element, for a ForEach of rows that dispatch or bind — each row keeps its own view store
ForEach(viewStore.each(.action(\.row).state(\.rows))) { RowView(store: $0) }
```

Prefer positions (`viewStore.state.each`) for rows that only display: a view store per element costs a few
microseconds per element on **every** change, even when nothing it reads changed (~13 ms per change at 3,000
elements), while positions from one view store cost ~30 µs for an unrelated change. Give a row its own view store
only when it dispatches or binds.

Deriving from any store gives a **pure stage** — something that follows a stream and keeps nothing a parent
holds. To observe one, hand it to the view that uses it, which keeps `@OwnedStore var viewStore` made from it
(`store.viewStore()` in its `init`); a feature's view does it for you.

```swift
let list: StoreProjection<BulkAction, [Row]> = store.projection(.action(\.bulk).state(\.rows))
let cell: StoreCollectionFocus<RowAction, Row> = store.projection(.action(\.row).state(\.rows), element: id)
let child: StoreProjection<ChildAction, Child?> = store.projection(.action(\.child).state(\.child))
```

The same `.state(\.rows)` resolves to a **reading** lane for a projection (which reads) and to a **keyed**
lane for `liftCollection` (which writes per element) — the host decides, with no ambiguity.

### transpose and traverse — a store of optional becomes an optional store

To hand a child `Feature` a store of the **unwrapped** value, invert the two type constructors:
`Store<Optional<T>>` becomes `Optional<Store<T>>` — the store analogue of transposing `Optional<[T]>` ⇄
`[Optional<T>]`. Two spellings, both on the `ViewStore`:

- `viewStore.transpose()` — no arguments, for a view store whose **own** state is `T?` or `Presentation<T>`.
- `viewStore.traverse(scope)` — map then transpose: project a `T?` or `Presentation<T>` slot through a scope and
  swap in one step.

Deciding *whether* the value is there is a read, so both live on the `ViewStore` and the calling view depends on the
**presence edge only**. What they return is a pure ``StoreOptionalFocus``: a store of the unwrapped value that holds
its last present value while the child animates away. The view that uses it keeps its own view store over it.

```swift
// in a view body:
viewStore.traverse(.action(\.child).state(\.child)) // StoreOptionalFocus<ChildAction, Child>?
    .map { ChildFeature.view(store: $0, environment: world.childEnv) } // View? — the feature's view keeps its view store

// a lane no key path expresses — the top of a navigation stack:
viewStore.traverse(action: AppAction.detail, state: { $0.stack.last })
```

Outside SwiftUI, presence is plain state: follow `store.stateStream.map { $0.child != nil }.removeDuplicates()`,
and on `true` build `StoreOptionalFocus(store.projection(…), present: value)` for the child screen.

> `transpose` plays the role of `sequence`, and `traverse` of `traverse` (map, then sequence), but a `Store` is
> not `Traversable`, so the swap claims no traversal law. It works because a view store knows the current value,
> which decides the nesting at call time. Once the source reads `nil`, the unwrapped store holds the last present
> value, so it never force-unwraps and keeps a dismissing screen steady.

### Presentation — the flicker-free child

For an animated modal, prefer `Presentation` (`presented` / `dismissing(last:)` / `dismissed`) over a
bare `T?`. Its `traverse` form keeps the child store live through **both** `presented` and `dismissing`, going
`nil` only at `dismissed` — so the sheet renders its last value steady as SwiftUI animates it out, with no flicker:

```swift
.sheet(item: viewStore.binding(.state(\.editor).action(\.editor))) { _ in
    if let editor = viewStore.traverse(.action(\.editor.child).state(\.editor)) {
        EditorFeature.view(store: editor, environment: world.editorEnv)
    }
}
```

### One element of a collection

``StoreCollectionFocus`` is a pure stage for one element: `store.projection(scope, element: id)` — by `id`, custom id
`.state(\.rows, id: \.slug)`, position `.state(indexed:)` or key `.state(dictionary:)` — with the `ElementAction`
envelope, and an optional element because it can go away. In a view, `viewStore.each(scope)` gives one store per
element for a `ForEach` — a ``StoreOptionalFocus`` (holding the last value while the row animates away) identified by
the element's id — and the row keeps its own view store:

```swift
ForEach(viewStore.each(.action(\.row).state(\.rows))) { row in
    RowView(store: row) // or RowFeature.view(store: row, …)
}

struct RowView: View {
    @OwnedStore var viewStore: ViewStore<RowAction, Row>
    init(store: some StoreType<RowAction, Row>) { _viewStore = OwnedStore(wrappedValue: store.viewStore()) }
    var body: some View { … }
}
```

Each row keeps its own view store: it redraws only for its own element, is made once per id, and survives reorders.
The list's body depends on the ids only, never on a row's contents. For one element outside a loop,
`viewStore.traverse(scope, element: id)` reads its presence and returns the same kind of store.

Finding the element: by position and by key it's O(1). By **id** each row's stage keeps a hint — where it last found
its element — and searches outward from it, so an element that moved by `k` costs `k` steps: O(1) for an insert or
remove, O(k) for a block of `k`, O(n) per row only after a shuffle, sort or reverse. The hint belongs to that row's
subscription; nothing is cached in the list. Measured with 1,000 owned rows (release): building them ~290 ms, one row
change ~7 ms, an insert at the top ~8 ms, a full reverse ~330 ms (O(n²) — every row walks its distance). A `List`
builds only its visible rows, so a real screen pays for those alone.

By position follows the *position*: after a removal the same index holds another element. Prefer ids unless the list
never changes shape.

## Two-way bindings

A store-backed `Binding` reads state and *dispatches* on write (the reducer stays the only writer). Bindings
live on the view store. A binding takes the same axis pair as every host — a `.state(…)` read and a `.action(…)` embed of the same value type —
so the slots can't be crossed and each offers only its own strategies (`\.case` / prism / `review:` /
`preview:` for actions, key path / closure / lens for state):

```swift
// action case:
TextField("Name", text: viewStore.binding(.state(\.name).action(\.setName)))
// or a transform, wrapping the closure in .action(review:):
TextField("Name", text: viewStore.binding(.state(\.name).action(review: { ViewAction.setName($0) })))

// a field of a collection element — inside RowView above, on the row's own view store:
TextField("Name", text: viewStore.binding(.state(\.name).action(\.setName)))
```

## See Also

- <doc:Lifting>
- <doc:Navigation>
- ``Relay/Scope``
- ``ElementAction``
- ``StoreProjection``
