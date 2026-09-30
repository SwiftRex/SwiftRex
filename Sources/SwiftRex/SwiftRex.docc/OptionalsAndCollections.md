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

// an optional child — its presence, then the child's own store
if let child = viewStore.focus(.state(\.child), .action(\.child)).transpose() { ChildFeature.view(store: child, environment: world.childEnv) }

// one element by id, through a closure lane
if let cell = viewStore.transpose(action: { AppAction.row(id, $0) }, state: { $0.rows.first { $0.id == id } }) { … }
```

Projections narrow types for whoever *follows* the store (`store.projection(…)` then `@OwnedStore` / a
feature's view) — a plain ``StoreProjection`` has no state to read, only a stream to follow:

```swift
let list: StoreProjection<BulkAction, [Row]> = store.projection(.action(AppAction.prism.bulk).state(\.rows))
let cell: StoreProjection<RowAction, Row?> = store.projection(.action(AppAction.prism.row).state(\.rows), element: id)
let child: StoreProjection<ChildAction, Child?> = store.projection(.action(AppAction.prism.child).state(\.child))
```

The same `.state(\.rows)` resolves to a **reading** lane for a projection (which reads) and to a **keyed**
lane for `liftCollection` (which writes per element) — the host decides, with no ambiguity.

### transpose — a store of optional becomes an optional store

To hand a child `Feature` a store of the **unwrapped** value, invert the two type constructors with
`transpose()`: `Store<Optional<T>>` becomes `Optional<Store<T>>` — the store analogue of transposing
`Optional<[T]>` ⇄ `[Optional<T>]`.

```swift
// in a view body — on the view store; the view depends on the presence edge only:
viewStore.focus(.state(\.child), .action(\.child))   // ViewStore<ChildAction, Child?>  — store of optional
    .transpose()                                        // StoreProjection<…, Child>?      — optional store of unwrapped
    .map { ChildFeature.view(store: $0, environment: world.childEnv) }   // View? — nil if the child is gone

// a lane no key path expresses:
viewStore.transpose(action: { AppAction.row(id, $0) }, state: { $0.rows.first { $0.id == id } })
```

`transpose` exists only on `ViewStore`: deciding presence is a *read*, and only a view store can read.

> It is deliberately **not** called `sequence`: a `Store` is not `Traversable`, so the swap claims no
> traversal law. It works because a view store knows the current value, which decides the nesting at call
> time. Once the source reads `nil`, the unwrapped store holds the last present value, so it never
> force-unwraps and keeps a dismissing screen steady.

### Presentation — the flicker-free child

For an animated modal, prefer ``Presentation`` (`presented` / `dismissing(last:)` / `dismissed`) over a
bare `T?`. Its `transpose()` overload (on the view store) keeps the child store live through **both**
`presented` and `dismissing`, going `nil` only at `dismissed` — so the sheet renders its last value steady as
SwiftUI animates it out, with no flicker:

```swift
.presenting(viewStore, \.editor, dismiss: .dismissEditor) { _ in
    if let editor = viewStore.focus(.state(\.editor), .action(\.editor)).transpose() {
        EditorFeature.view(store: editor, environment: world.editorEnv)
    }
}
```

## Two-way bindings

A store-backed `Binding` reads state and *dispatches* on write (the reducer stays the only writer). Bindings
live on the view store (`ViewStore`, focused or not). It takes
the same axis pair as every host — a `.state(…)` read and a `.action(…)` embed of the same value type —
so the slots can't be crossed and each offers only its own strategies (`\.case` / prism / `review:` /
`preview:` for actions, key path / closure / lens for state):

```swift
// action case:
TextField("Name", text: viewStore.binding(.state(\.name), dispatch: .action(\.setName)))
// or a transform, wrapping the closure in .action(review:):
TextField("Name", text: viewStore.binding(.state(\.name), dispatch: .action(review: { ViewAction.setName($0) })))

// a field of a collection element — scope the row node, then bind:
ForEach(store.each(\.rows)) { row in
    TextField("Name", text: row.scoped(action: .action(review: { AppAction.row(row.id, $0) }))
        .binding(.state(\.name), dispatch: .action(\.setName)))
}
```

## See Also

- <doc:Lifting>
- <doc:Navigation>
- ``Relay/Scope``
- ``ElementAction``
- ``StoreProjection``
- ``Presentation``
