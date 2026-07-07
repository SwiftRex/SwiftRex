# ``SwiftRex/Reaction``

The action-clock branch of a ``Consequence`` — what reacting to one action changes and does.

## Overview

A `Reaction<Action, State, Environment>` pairs a ``ReducerOutcome`` (the state mutation to apply in phase 2, or ``ReducerOutcome/unchanged``) with a `Reader<PostReducerContext, Effect>` (the effect to schedule in phase 3). Its two monoidal generators are `reduce` and `produce`; the ``Store`` is what *mutates* and *performs* them.

### Building one

- ``reduce(_:)`` — describe a state mutation, no effect.
- ``produce(_:)`` — describe an effect, no mutation.
- chain them — `.reduce { … }.produce { ctx in … }` — for both.
- ``doNothing`` — neither (the monoid identity); the ``Store`` fires no notifications for it.

```swift
Behavior<AppAction, AppState, AppEnvironment>.react { action, _ in
    switch action {
    case .increment:          .reduce  { $0.count += 1 }
    case .fetch(let query):   .produce { ctx in ctx.environment.api.search(query).asEffect() }
    case .fetchAndShow(let q): .reduce { $0.isLoading = true }
                               .produce { ctx in ctx.environment.api.search(q).asEffect() }
    case .noop:               .doNothing
    }
}
```

### The algebra — a product monoid

`Reaction` is a `Monoid`: ``combine(_:_:)`` composes componentwise — the ``ReducerOutcome`` mutations fold **sequentially** (lhs then rhs, same `inout State`), the effect `Reader`s merge in **parallel** — with ``doNothing`` as the identity. This is the *action-clock* half of a ``Consequence``; the *state-clock* half is ``Supervision``. See <doc:Algebra>.

## Topics

### Building a Reaction

- ``reduce(_:)``
- ``produce(_:)``
- ``doNothing``

## See Also

- ``Consequence``
- ``Supervision``
- ``ReducerOutcome``
- ``Effect``
- ``PostReducerContext``
- <doc:Algebra>
