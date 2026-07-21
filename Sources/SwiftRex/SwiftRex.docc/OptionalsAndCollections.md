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
``Reducer/liftCollection(_:)``-style optics, and a store can never be *absent* — see the view side below.)

## liftCollection and liftEach — the 0-or-n hosts

``Behavior/liftCollection(_:)`` routes an addressed action to **one** element; ``Behavior/liftEach(_:)``
broadcasts to **every** element. Both take the same leading-dot scope — no `Relay.Scope.identity` prefix:

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

## The view side — projecting stores

A view reads through a ``StoreProjection``. There are three read shapes for variable state:

```swift
// whole collection — the list view iterates this, then projects each row
let list: StoreProjection<BulkAction, [Row]> = store.projection(.action(AppAction.prism.bulk).state(\.rows))

// one element by id — the projected state is Row? (the view unwraps)
let cell: StoreProjection<RowAction, Row?> = store.projection(.action(AppAction.prism.row).state(\.rows), element: id)

// an optional child — likewise Value?
let child: StoreProjection<ChildAction, Child?> = store.projection(.action(AppAction.prism.child).state(\.child))
```

The same `.state(\.rows)` resolves to a **reading** lane for a projection (which reads) and to a **keyed**
lane for `liftCollection` (which writes per element) — the host decides, with no ambiguity.

### transpose — a store of optional becomes an optional store

To hand a child `Feature` a store of the **unwrapped** value, invert the two type constructors with
``StoreType/transpose()``: `Store<Optional<T>>` becomes `Optional<Store<T>>` — the store analogue of
transposing `Optional<[T]>` ⇄ `[Optional<T>]`.

```swift
store.projection(scope, element: id)   // StoreProjection<RowAction, Row?>   — store of optional
    .transpose()                        // StoreProjection<RowAction, Row>?   — optional store of unwrapped
    .map { RowFeature.view(store: $0, environment: world.rowEnv) }   // View?  — nil if the row was gone
// then:  if let rowView { rowView }
```

> It is deliberately **not** called `sequence`: a `Store` is not `Traversable`, so the swap claims no
> traversal law. It works because a store is *peekable* — the current value decides the nesting at call
> time. The unwrapped store falls back to the value captured at `transpose()`-time on the transient frame
> where the source reads `nil`, so it never force-unwraps and holds the last value steady across a
> dismissal.

### Presentation — the flicker-free child

For an animated modal, prefer ``Presentation`` (`presented` / `dismissing(last:)` / `dismissed`) over a
bare `T?`. Its `transpose()` overload keeps the child store live through **both** `presented` and
`dismissing`, going `nil` only at `dismissed` — so the sheet renders its last value steady as SwiftUI
animates it out, with no flicker:

```swift
.presenting(store, \.editor, dismiss: .dismissEditor) { _ in
    if let editorView = store.projection(editorScope).transpose().map({ EditorFeature.view(store: $0, environment: world.editorEnv) }) {
        editorView
    }
}
```

## Two-way bindings

A store-backed `Binding` reads state and *dispatches* on write (the reducer stays the only writer). It takes
the same axis pair as every host — a `.state(…)` read and a `.action(…)` embed of the same value type —
so the slots can't be crossed and each offers only its own strategies (`\.case` / prism / `review:` /
`preview:` for actions, key path / closure / lens for state):

```swift
// action case:
TextField("Name", text: store.binding(.state(\.name), dispatch: .action(\.setName)))
// or a transform, wrapping the closure in .action(review:):
TextField("Name", text: store.binding(.state(\.name), dispatch: .action(review: { ViewAction.setName($0) })))

// a field of a collection element — free, via transpose():
if let rowStore = store.projection(scope, element: id).transpose() {
    TextField("Name", text: rowStore.binding(.state(\.name), dispatch: .action(\.setName)))
}
```

## See Also

- <doc:Lifting>
- <doc:Navigation>
- ``Relay/Scope``
- ``ElementAction``
- ``StoreProjection``
- ``Presentation``
