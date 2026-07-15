# ``SwiftRex/Middleware``

The effect-only layer of a feature — a simplified ``Behavior`` that reads state and the environment and runs side-effects, but never mutates state. It carries both effect axes: action-driven ``produce(_:)`` and state-driven ``supervise(_:)``.

## Overview

A `Middleware<Action, State, Environment>` owns the two effect concerns a feature can have, and *only* those — state mutation is ``Reducer``'s job:

- ``produce(_:)`` — the **Effect Producer**: maps an action (and a pre-mutation ``PreReducerContext``) to a `Reader<PostReducerContext, Effect>` the ``Store`` *performs* in phase 3 (post-mutation), with access to the `Environment` and committed `liveState`. This is the *action-driven* effect.
- ``supervise(_:)`` — the **Effect Supervisor**: maps the *state* to a ``Supervision`` — the channels to ``Keep`` alive while that state holds. The ``Store`` *supervises* them. This is the *state-driven* effect. See <doc:StateDrivenEffects>.

```swift
let search = Middleware<AppAction, AppState, API>
    .produce { action, _ in
        guard case .search(let query) = action else { return .doNothing }
        return Producer { ctx in ctx.environment.search(query).asEffect(AppAction.results) }
    }
    .supervise { state in
        Supervision { env in state.isConnected ? [env.makeFeedChannel()] : [] }
    }
```

Both builders exist as **static** factories and **instance** methods, so a `.produce { … }.supervise { … }` chain is an `<>` fold of single-concern middlewares. Combine a `Reducer` with a `Middleware` to get a ``Behavior``.

### The two-phase context

`handle` receives the action plus a ``PreReducerContext`` — a `@MainActor`, deliberately **non-`Sendable`** snapshot of the pre-mutation world (`stateBefore`, `source`) — and returns a `Reader<PostReducerContext, Effect>` that the ``Store`` runs in phase 3, *after* the reducers. The compiler stops you from capturing the pre-context into the `@Sendable` phase-3 closure; copy `context.stateBefore` into a local `let` when you need a before/after comparison:

```swift
let logger = Middleware<AppAction, AppState, Logger>.handle { action, context in
    let before = context.stateBefore                    // phase 1 — pre-mutation
    return Producer { ctx in
        ctx.environment.log(action, before: before)     // phase 3 — runs with the environment
        return .empty
    }
}
```

``PostReducerContext`` carries `environment` and the committed `liveState` (a `@MainActor` read; from a non-isolated context use `await MainActor.run { ctx.liveState }`). The reactive companion products — `SwiftRex.Combine`, `SwiftRex.RxSwift`, `SwiftRex.ReactiveSwift`, `SwiftRex.ReactiveConcurrency` — each add a `readLiveState()` extension on `PostReducerContext` returning a one-element stream that hops to `@MainActor` automatically, so post-mutation state can feed a pipeline:

```swift
return .produce { ctx in
    ctx.readLiveState()                                 // e.g. Publisher<State, Never>
        .flatMap { state in ctx.environment.api.save(state.draft) }
        .asEffect()
}
```

The state is read lazily — only when a subscriber attaches — so it always reflects the post-mutation value of the current dispatch cycle.

### The algebra — a parallel monoid

`Middleware` is a `Monoid`: ``combine(_:_:)`` runs both middlewares on the same action and **merges their effects**, and **unions their supervisors** (the desired channel sets combine); ``identity`` produces no effect and keeps nothing. See <doc:Algebra>.

### Scaling a feature up

A middleware written at *local* types is lifted to your app's *global* types before composing:

- ``lift(_:)`` — all three axes at once.
- ``liftAction(_:)`` / ``liftState(_:)`` / ``liftEnvironment(_:)`` — one axis at a time (`Prism`/`KeyPath`/`Lens`/`AffineTraversal`/projection closure).
- ``liftCollection(action:embed:stateContainer:elements:)`` / ``liftEach(action:embed:each:stateContainer:)`` — run a per-element middleware across a keyed collection, or broadcast to all elements.

Every lift carries **both** effect axes — including `supervise`: a lifted middleware's channels are re-embedded and (for collections) per-element stamped. Use the `on(…)` family to route by action case without a manual `guard case` — the same Prism / KeyPath / predicate families documented on ``Behavior``, minus the `reduce:` parameter (a middleware never mutates).

### Becoming a Behavior

``asBehavior`` lifts a `Middleware` into a ``Behavior`` whose state mutation is always ``ReducerOutcome/unchanged`` — the bridge for combining pure effects with reducers under one type. Its `supervise` axis carries through unchanged.

## Topics

### Creating a Middleware

- ``produce(_:)``
- ``supervise(_:)``
- ``handle(_:)``

### Composing

- ``combine(_:_:)``

### Lifting to a Larger Scope

- ``lift(_:)``
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
