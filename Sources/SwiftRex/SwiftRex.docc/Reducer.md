# ``SwiftRex/Reducer``

The one place state changes — a pure function from an action to an in-place mutation.

## Overview

A `Reducer<ActionType, StateType>` maps an action to an `EndoMut<State>` — an in-place endomorphism on your state. It is the **only** layer in SwiftRex allowed to mutate state, and it does so purely: no side effects, no async work, no environment. Effects live in ``Middleware``; the two combine into a ``Behavior``.

```swift
let counter = Reducer<CounterAction, Int>.reduce { action, state in
    switch action {
    case .increment: state += 1
    case .decrement: state -= 1
    case .reset:     state = 0
    }
}
```

### Creating one

There are four `reduce` factories — pick whichever reads best; they all build the same value:

- `reduce { action, state in … }` — the idiomatic **`inout`** form (zero-copy).
- `reduce { action, state in newState }` — the **pure-return** form, converted to `inout` internally.
- `reduce { action in EndoMut { … } }` — return an `EndoMut` directly; handy when composing endomorphisms or optimising a hot path.
- `reduce { action in Endo { … } }` — the value-level `Endo` variant (bridges to `EndoMut`).

### The algebra — a sequential monoid

`Reducer` is a `Monoid`. ``combine(_:_:)`` runs `lhs` then `rhs` on the **same** `inout` state (order matters; `rhs` sees `lhs`'s change); ``identity`` mutates nothing. This is precisely the structure of `EndoMut`'s monoid lifted over actions — see <doc:Algebra>. Build composite reducers with the `@ReducerBuilder` DSL:

```swift
let app = Reducer.compose {
    counterReducer
    historyReducer            // runs after counterReducer, sees its mutation
}
```

### Scaling a feature up

A reducer written at *local* types is lifted to your app's *global* types before composing:

- **`lift`** — map the action (a `KeyPath`/`Prism`) and focus the state (a `WritableKeyPath`/`Lens`/`AffineTraversal`), together or one axis at a time.
- **`liftCollection`** — run a per-element reducer across an `Identifiable`/custom-keyed collection or a dictionary, addressed by id.
- **`liftEach`** — the broadcast form: apply to *every* element.

See <doc:Algebra> for why lifting composes cleanly, and ``ElementAction`` for how element actions are addressed.

### Becoming a Behavior

``asBehavior()`` turns a `Reducer` into a ``Behavior`` whose effect is always empty — the bridge for combining pure reducers with effectful middleware under one type.

## Topics

### Creating a Reducer

- ``reduce(_:)``

### Composing

- ``combine(_:_:)``
- ``identity``
- ``mconcat(_:)``
- ``sconcat(_:_:)``
- ``ReducerBuilder``

### Lifting to a Larger Scope

- ``lift(_:)``
- ``liftCollection(action:stateContainer:)``
- ``liftEach(action:each:stateContainer:)``

### Bridging

- ``asBehavior()``

## See Also

- ``Behavior``
- ``Middleware``
- ``ReducerOutcome``
- <doc:Algebra>
