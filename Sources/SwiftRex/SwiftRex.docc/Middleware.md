# ``SwiftRex/Middleware``

The effect-only layer of a feature — it reads state and the environment and runs side-effects, but never mutates state. It carries both effect axes: action-driven ``react(_:)`` and state-driven ``supervise(_:)``.

## Overview

A `Middleware<Action, State, Environment>` owns the two effect concerns a feature can have, and *only* those — state mutation is ``Reducer``'s job:

- ``react(_:)`` — maps an action (and a pre-mutation ``PreReducerContext``) to a ``Reaction``, a `Reader<PostReducerContext, Effect>` the ``Store`` resolves in phase 3 (post-mutation), with access to the `Environment` and committed `liveState`. This is the *action-driven* effect (Elm's `Cmd`).
- ``supervise(_:)`` — maps the *state* to a ``Keep`` of ``Channel``s the engine keeps alive while that state holds. This is the *state-driven* effect (Elm's `Sub`). See <doc:StateDrivenEffects>.

```swift
let search = Middleware<AppAction, AppState, API>
    .react { action, _ in
        guard case .search(let query) = action else { return Reaction { _ in .empty } }
        return Reaction { ctx in ctx.environment.search(query).asEffect(AppAction.results) }
    }
    .supervise { state in
        Keep { env in state.isConnected ? [env.makeFeedChannel()] : [] }
    }
```

Both builders exist as **static** factories and **instance** methods, so a `.react { … }.supervise { … }` chain is an `<>` fold of single-concern middlewares. Combine a `Reducer` with a `Middleware` to get a ``Behavior``.

### The algebra — a parallel monoid

`Middleware` is a `Monoid`: ``combine(_:_:)`` runs both middlewares on the same action and **merges their effects**, and **unions their supervisors** (the desired channel sets combine); ``identity`` produces no effect and keeps nothing. See <doc:Algebra>.

### Scaling a feature up

A middleware written at *local* types is lifted to your app's *global* types before composing:

- ``lift(action:state:environment:)`` — all three axes at once.
- ``liftAction(_:)`` / ``liftState(_:)`` / ``liftEnvironment(_:)`` — one axis at a time (`Prism`/`KeyPath`/`Lens`/`AffineTraversal`/projection closure).
- ``liftCollection(action:embed:stateContainer:elements:)`` / ``liftEach(action:embed:each:stateContainer:)`` — run a per-element middleware across a keyed collection, or broadcast to all elements.

Every lift carries **both** effect axes — including `supervise`: a lifted middleware's channels are re-embedded and (for collections) per-element stamped. Use the `on(…)` family to route by action case without a manual `guard case`.

### Becoming a Behavior

``asBehavior`` lifts a `Middleware` into a ``Behavior`` whose state mutation is always ``ReducerOutcome/unchanged`` — the bridge for combining pure effects with reducers under one type. Its `supervise` axis carries through unchanged.

## Topics

### Creating a Middleware

- ``react(_:)``
- ``supervise(_:)``
- ``handle(_:)``

### Composing

- ``combine(_:_:)``

### Lifting to a Larger Scope

- ``lift(action:state:environment:)``
- ``liftAction(_:)``
- ``liftState(_:)``
- ``liftEnvironment(_:)``
- ``liftCollection(action:embed:stateContainer:elements:)``
- ``liftEach(action:embed:each:stateContainer:)``

### Bridging

- ``asBehavior``

## See Also

- ``Reducer``
- ``Behavior``
- ``Effect``
- ``PreReducerContext``
- ``PostReducerContext``
- <doc:StateDrivenEffects>
- <doc:Algebra>
