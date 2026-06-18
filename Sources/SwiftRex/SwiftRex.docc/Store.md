# ``SwiftRex/Store``

The single interpreter — the only place state mutates and effects run.

## Overview

`Store<Action, State, Environment>` owns your app's state and is the sole executor of effects. You dispatch actions; for each one it runs the ``Behavior`` in three phases — compute the ``Consequence`` against pre-mutation state, apply the mutation in place (bracketed by `willChange`/`didChange` notifications), then resolve and schedule the effect against post-mutation state. Actions produced by effects loop back. Its whole surface is `@MainActor`, so `withAnimation { store.dispatch(...) }` works with no special API.

The `Store` is the interpreter for the inert values the rest of the library builds (`IO` at the program's edge). See <doc:Algebra> for the guarantees this yields: one notification per state-changing action, zero-copy mutation, committed-state effects, and FIFO-safe re-entrancy.

### Creating one

```swift
let store = Store(initial: AppState(), behavior: appBehavior, environment: env)
```

When `Environment == Void` a convenience initialiser omits it; another accepts an injected `Clock`/`Date`/`UUID` for deterministic time in tests.

### Dispatching & observing

``dispatch(_:source:)`` enqueues an action (synchronous from `@MainActor`). ``observe(willChange:didChange:)`` registers a `@MainActor` observer and returns a ``SubscriptionToken`` you must retain — releasing it cancels the observation.

### Narrowing for views

``StoreType/projection(action:state:)`` maps the store to a local action/state slice (a stateless ``StoreProjection``); ``StoreType/buffer()`` wraps it in a deduplicating ``StoreBuffer``. Run-away dispatch loops are cut off via ``StoreHooks``.

## Topics

### Dispatching

- ``dispatch(_:source:)``

### Observing

- ``observe(willChange:didChange:)``

### Narrowing for Views

- ``StoreType/projection(action:state:)``
- ``StoreType/buffer()``

### Diagnostics

- ``StoreHooks``
- ``StoreReentranceInfo``

## See Also

- ``StoreType``
- ``StoreProjection``
- ``StoreBuffer``
- ``Behavior``
- <doc:Algebra>
