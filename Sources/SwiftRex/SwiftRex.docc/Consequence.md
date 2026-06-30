# ``SwiftRex/Consequence``

A single thing a ``Behavior`` does — a **reaction** to an action, or a **supervision** of state.

## Overview

A ``Behavior`` *is* a monoid of consequences: `Behavior` is `[Consequence]`, with `[]` the identity and `+` the composition. Each `Consequence<State, Environment, Action>` is one of two **clocks**:

- ``reaction(_:)`` — the **action clock**. Given an action and the pre-mutation ``PreReducerContext``, it produces a ``Reaction`` (a `reduce` and/or a `produce`), scheduled once per action.
- ``supervision(_:)`` — the **state clock**. Given the post-mutation state, it produces a ``Supervision`` (the channels to *keep*), reconciled by diff after every change — independent of whether any action reached this behavior, which is what makes it survive time-travel.

You rarely build a `Consequence` by hand. The ``Behavior`` and ``Middleware`` builders construct the right case for you:

```swift
Behavior<AppAction, AppState, AppEnvironment>
    .reduce    { action, state in /* … */ }   // → .reaction (mutation)
    .produce   { action, ctx   in /* … */ }   // → .reaction (effect)
    .supervise { state         in /* … */ }   // → .supervision
```

### Describe, don't do

Both cases are pure *descriptions*. `reduce` describes a mutation, `produce` describes an effect, `supervise` describes the channels to keep — the ``Store`` is the boundary that **mutates**, **performs**, and **keeps**. Nothing in a consequence runs on its own.

### The two branches

| case | branch type | clock | the Store… |
|---|---|---|---|
| ``reaction(_:)`` | ``Reaction`` (`reduce` \| `produce`) | action | mutates · performs |
| ``supervision(_:)`` | ``Supervision`` (a ``Keep`` of channels) | state | keeps |

Because `Behavior` is the free monoid `[Consequence]`, composing whole features is just concatenating their consequence lists — reactions fold (mutations sequential, effects parallel) and supervisions union. See <doc:Algebra>.

## Topics

### The two clocks

- ``reaction(_:)``
- ``supervision(_:)``

### The branch types

- ``Reaction``
- ``Supervision``
- ``Keep``

## See Also

- ``Behavior``
- ``Reaction``
- ``Supervision``
- <doc:StateDrivenEffects>
- <doc:Algebra>
