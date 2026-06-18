# ``SwiftRex/Middleware``

The effect-only half of a feature — it reads state and the environment and returns an ``Effect``, but never mutates state.

## Overview

A `Middleware<Action, State, Environment>` maps an action and a pre-mutation ``PreReducerContext`` to a `Reader<PostReducerContext, Effect>` — a deferred effect the ``Store`` resolves in phase 3 (post-mutation), with access to the `Environment` and the committed `liveState`. It is the only layer allowed side effects; it never changes state — that is ``Reducer``. Combine a `Reducer` and a `Middleware` to get a ``Behavior``.

```swift
let search = Middleware<AppAction, AppState, API>.handle { action, _ in
    guard case .search(let query) = action else { return Reader { _ in .empty } }
    return Reader { ctx in
        ctx.environment.search(query).asEffect(AppAction.results)
    }
}
```

### The algebra — a parallel monoid

`Middleware` is a `Monoid`: ``combine(_:_:)`` runs both middlewares on the same action and **merges their effects**; ``identity`` produces no effect. See <doc:Algebra>.

### Scaling a feature up

A middleware written at *local* types is lifted to your app's *global* types before composing:

- ``lift(action:state:environment:)`` — all three axes at once.
- ``liftAction(_:)`` / ``liftState(_:)`` / ``liftEnvironment(_:)`` — one axis at a time (`Prism`/`KeyPath`/`Lens`/`AffineTraversal`/projection closure).
- ``liftCollection(action:embed:stateContainer:)`` / ``liftEach(action:embed:each:stateContainer:)`` — run a per-element middleware across a keyed collection, or broadcast to all elements.

Use the `on(…)` family to route by action case without a manual `guard case`.

### Becoming a Behavior

``asBehavior`` lifts a `Middleware` into a ``Behavior`` whose state mutation is always ``ReducerOutcome/unchanged`` — the bridge for combining pure effects with reducers under one type.

## Topics

### Creating a Middleware

- ``handle(_:)``

### Composing

- ``combine(_:_:)``

### Lifting to a Larger Scope

- ``lift(action:state:environment:)``
- ``liftAction(_:)``
- ``liftState(_:)``
- ``liftEnvironment(_:)``
- ``liftCollection(action:embed:stateContainer:)``
- ``liftEach(action:embed:each:stateContainer:)``

### Bridging

- ``asBehavior``

## See Also

- ``Reducer``
- ``Behavior``
- ``Effect``
- ``PreReducerContext``
- ``PostReducerContext``
- <doc:Algebra>
