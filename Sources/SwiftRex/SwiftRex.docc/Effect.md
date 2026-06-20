# ``SwiftRex/Effect``

A lazy, framework-agnostic description of side-effecting work — it runs only when the Store executes it.

## Overview

An `Effect<Action>` is the unit of side effect a ``Middleware`` (or a ``Behavior``) returns. It is **inert until run**: constructing one starts nothing — no `Task`, no network call — until the ``Store`` subscribes to it. That is what keeps the reducer/behavior layer pure. An effect produces zero or more actions that loop back into the Store.

`Effect` exposes no `Task`, `AsyncStream`, `Publisher`, or `Observable` in its API — those live in the companion products (`SwiftRex.SwiftConcurrency`, `SwiftRex.Combine`, `SwiftRex.RxSwift`, `SwiftRex.ReactiveSwift`, `SwiftRex.ReactiveConcurrency`), each adding `asEffect()` bridges.

### Creating one

- ``just(_:scheduling:file:function:line:)`` — dispatch a single action.
- ``sequence(_:scheduling:file:function:line:)`` — dispatch a fixed list of actions.
- ``channel(value:scheduling:file:function:line:_:)`` — a long-lived, *pipeable* effect.
- ``empty`` — do nothing (the monoid identity).
- a companion product's `asEffect()` — bridge a publisher / observable / async sequence.

### Recreate vs. pipe

The factories above are **recreate-on-dispatch**: each dispatch starts fresh work, and an id-scoped ``EffectScheduling`` (replace / debounce / throttle) cancels the displaced run. That is the right model for one-shot work — a search request, a save.

For *long-lived* work that must **not** be torn down — a WebSocket, a location or audio pipeline — use ``channel(value:scheduling:file:function:line:_:)``. The Store opens it once and pipes every subsequent value into the **same** running effect, with `debounce`/`throttle` gating the value delivery rather than the effect's lifetime. See ``ChannelHandler``.

### Scheduling

Attach an ``EffectScheduling`` policy with ``scheduling(_:)``: run immediately, or under an id so the Store can debounce, throttle, replace, or cancel it in flight. The mutable bookkeeping (timers, in-flight handles) lives in the ``Store``, never in the effect.

```swift
api.search(query).asEffect(AppAction.results)
    .scheduling(.debounce(id: "search", delay: .milliseconds(300)))
```

### The algebra — a parallel monoid

`Effect` is a `Monoid`: ``combine(_:_:)`` merges two effects so the ``Store`` runs them **concurrently**, and ``empty`` is the identity. It is a Functor via ``map(_:)``. See <doc:Algebra>.

## Topics

### Creating an Effect

- ``just(_:scheduling:file:function:line:)``
- ``sequence(_:scheduling:file:function:line:)``
- ``empty``

### Pipeable channels

- ``channel(value:scheduling:file:function:line:_:)``
- ``channel(value:scheduling:bufferingPolicy:file:function:line:consume:)``
- ``pipe(_:into:file:function:line:)``
- ``ChannelHandler``

### Scheduling

- ``scheduling(_:)``

### Transforming & Composing

- ``map(_:)``
- ``combine(_:_:)``
- ``identity``

## See Also

- ``EffectScheduling``
- ``Middleware``
- ``Behavior``
- ``SubscriptionToken``
- <doc:Algebra>
