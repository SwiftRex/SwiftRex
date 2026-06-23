# ``SwiftRex/Behavior``

The primary composition unit — a ``Reducer``, a ``Middleware``, and a state-driven supervisor fused into one liftable, composable value.

## Overview

A `Behavior<Action, State, Environment>` folds three independent concerns of a feature, each a fluent builder that composes by `<>`:

- ``reduce(_:)`` — the **state change**: a pure `(Action, inout State) -> Void`.
- ``react(_:)`` — the **action-driven effect**: an action causes a ``Reaction`` (Elm's `Cmd`).
- ``supervise(_:)`` — the **state-driven effect**: the *state* keeps a ``Keep`` of ``Channel``s alive (Elm's `Sub`). See <doc:StateDrivenEffects>.

```swift
let room = Behavior<RoomAction, RoomState, RoomEnv>
    .reduce { action, state in … }                 // what changes
    .react { action, ctx in … }                    // what to do because of an action
    .supervise { state in … }                      // what to keep alive while the state holds
```

Each builder exists as a **static** factory (`Behavior.reduce { … }`) and as an **instance** method (`someBehavior.react { … }`), so a fluent chain is exactly an `<>` fold — the chain above is three single-concern behaviors combined. You can also build from a closure (``handle(_:)``) returning a whole ``Consequence``, or pair the first two axes with `Behavior(reducer:middleware:)`; ``Reducer/asBehavior()`` and ``Middleware/asBehavior`` lift each half on its own (a `Middleware`'s own `supervise` axis carries through).

### The algebra — a flat fold of units

`Behavior` is a `Monoid`. ``combine(_:_:)`` runs both behaviors on the same action, folding their state mutations **sequentially** and merging their effects in **parallel** (its ``Consequence`` is a product monoid); ``identity`` does nothing and — crucially — composes away to a no-op that the ``Store`` skips entirely. Composition is a single flat pass over the underlying units, not a nested closure tree. See <doc:Algebra>.

```swift
let app = Behavior.combine(counter.lifted, profile.lifted)   // or counter.lifted <> profile.lifted
```

### Scaling a feature up

``lift(action:state:environment:)`` and the per-axis ``liftAction(_:)`` / ``liftState(_:)`` / ``liftEnvironment(_:)`` raise a feature from its local types to the app's global types; ``liftCollection(action:embed:stateContainer:elements:)`` and ``liftEach(action:embed:each:stateContainer:)`` run a per-element behavior across a collection. ``on(_:reduce:)`` and friends route by action case. Every lift carries **all three** axes — including `supervise`: a lifted feature's channels are re-embedded and (for collections) per-element stamped, so state-driven nav and per-row sockets just work. See <doc:Lifting>.

## Topics

### Building a Behavior

- ``reduce(_:)``
- ``react(_:)``
- ``supervise(_:)``
- ``handle(_:)``

### Composing

- ``combine(_:_:)``
- ``mconcat(_:)``
- ``sconcat(_:_:)``

### Lifting to a Larger Scope

- ``lift(action:state:environment:)``
- ``liftAction(_:)``
- ``liftState(_:)``
- ``liftEnvironment(_:)``
- ``liftCollection(action:embed:stateContainer:elements:)``
- ``liftEach(action:embed:each:stateContainer:)``

## See Also

- ``Reducer``
- ``Middleware``
- ``Consequence``
- ``ReducerOutcome``
- ``Store``
- <doc:StateDrivenEffects>
- <doc:Algebra>
