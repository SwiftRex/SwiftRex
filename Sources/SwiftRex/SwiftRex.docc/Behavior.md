# ``SwiftRex/Behavior``

The primary composition unit — a ``Reducer`` and a ``Middleware`` fused into one liftable, composable value.

## Overview

A `Behavior<Action, State, Environment>` maps an action and a pre-mutation ``PreReducerContext`` to a ``Consequence`` — the pair of *what state change to apply* and *what effect to run afterward*. It is how you usually build a feature: rather than wiring a ``Reducer`` and a ``Middleware`` separately, you express both in one value.

```swift
let form = Behavior<AppAction, AppState, API> { action, _ in
    guard case .submit(let data) = action else { return .doNothing }
    return .reduce { $0.isLoading = true }
        .react { ctx in ctx.environment.api.submit(data).asEffect(AppAction.submitted) }
}
```

Create one from a closure (``handle(_:)``), or from the two halves with `Behavior(reducer:middleware:)`; ``Reducer/asBehavior()`` and ``Middleware/asBehavior`` lift each half on its own.

### The algebra — a flat fold of units

`Behavior` is a `Monoid`. ``combine(_:_:)`` runs both behaviors on the same action, folding their state mutations **sequentially** and merging their effects in **parallel** (its ``Consequence`` is a product monoid); ``identity`` does nothing and — crucially — composes away to a no-op that the ``Store`` skips entirely. Composition is a single flat pass over the underlying units, not a nested closure tree. See <doc:Algebra>.

```swift
let app = Behavior.combine(counter.lifted, profile.lifted)   // or counter.lifted <> profile.lifted
```

### Scaling a feature up

``lift(action:state:environment:)`` and the per-axis ``liftAction(_:)`` / ``liftState(_:)`` / ``liftEnvironment(_:)`` raise a feature from its local types to the app's global types; ``liftCollection(action:embed:stateContainer:)`` and ``liftEach(action:embed:each:stateContainer:)`` run a per-element behavior across a collection. ``on(_:reduce:)`` and friends route by action case.

## Topics

### Creating a Behavior

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
- ``liftCollection(action:embed:stateContainer:)``
- ``liftEach(action:embed:each:stateContainer:)``

## See Also

- ``Reducer``
- ``Middleware``
- ``Consequence``
- ``ReducerOutcome``
- ``Store``
- <doc:Algebra>
