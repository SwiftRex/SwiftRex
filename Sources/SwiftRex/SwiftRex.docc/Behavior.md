# ``SwiftRex/Behavior``

The primary composition unit — a monoid of ``Consequence``s fusing a ``Reducer``, a ``Middleware``, and state-driven supervision into one liftable, composable value.

## Overview

A `Behavior<Action, State, Environment>` *is* `[Consequence]`. Three fluent builders describe a feature's concerns, each composing by `<>`:

- ``reduce(_:)`` — the **state change**: a pure `(Action, inout State) -> Void`. The ``Store`` *mutates*.
- ``produce(_:)`` — the **action-driven effect**: an action produces an ``Effect`` (Elm's `Cmd`). The ``Store`` *performs*.
- ``supervise(_:)`` — the **state-driven effect**: the *state* keeps a ``Supervision`` of ``Channel``s alive (Elm's `Sub`). The ``Store`` *keeps*. See <doc:StateDrivenEffects>.

```swift
let room = Behavior<RoomAction, RoomState, RoomEnv>
    .reduce { action, state in … }                 // what changes
    .produce { action, ctx in … }                    // what to do because of an action
    .supervise { state in … }                      // what to keep alive while the state holds
```

Each builder exists as a **static** factory (`Behavior.reduce { … }`) and as an **instance** method (`someBehavior.produce { … }`), so a fluent chain is exactly an `<>` fold. To share pre-work between a mutation and its effect, use the grouped ``react(_:)`` builder — it hands you the action and returns a whole ``Reaction``:

```swift
Behavior.react { action, _ in
    guard case .load(let id) = action else { return .doNothing }
    return .reduce  { $0.isLoading = true }
           .produce { ctx in ctx.environment.api.fetch(id).asEffect() }
}
```

You can also pair the reducer and middleware axes with `Behavior(reducer:middleware:)`; ``Reducer/asBehavior()`` and ``Middleware/asBehavior`` lift each half on its own (a `Middleware`'s own `supervise` axis carries through).

### The algebra — the free monoid `[Consequence]`

`Behavior` is a `Monoid` — literally the free monoid over its consequences: ``combine(_:_:)`` **concatenates** the lists, ``identity`` is `[]`. Composing runs both behaviors' reactions on the same pre-mutation state (mutations fold **sequentially**, effects merge in **parallel** — each ``Reaction`` is a product monoid) and **unions** their supervisions. It is a single flat pass, not a nested closure tree, and an all-no-op fold stays ``ReducerOutcome/unchanged`` so the ``Store`` skips the notification entirely. See <doc:Algebra>.

```swift
let app = Behavior.combine(counter.lifted, profile.lifted)   // or counter.lifted <> profile.lifted
```

### Scaling a feature up

``lift(action:state:environment:)`` and the per-axis ``liftAction(_:)`` / ``liftState(_:)`` / ``liftEnvironment(_:)`` raise a feature from its local types to the app's global types; ``liftCollection(action:embed:stateContainer:elements:)`` and ``liftEach(action:embed:each:stateContainer:)`` run a per-element behavior across a collection. ``on(_:reduce:)`` and friends route by action case. Every lift carries **all three** axes — including `supervise`: a lifted feature's channels are re-embedded and (for collections) per-element stamped, so state-driven nav and per-row sockets just work. See <doc:Lifting>.

## Topics

### Building a Behavior

- ``reduce(_:)``
- ``produce(_:)``
- ``supervise(_:)``
- ``react(_:)``
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
- ``Reaction``
- ``Supervision``
- ``ReducerOutcome``
- ``Store``
- <doc:StateDrivenEffects>
- <doc:Algebra>
