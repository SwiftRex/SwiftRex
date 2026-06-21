# ``SwiftRex/Consequence``

The outcome of handling an action — a state change paired with a deferred effect.

## Overview

A `Consequence<State, Environment, Action>` is what a ``Behavior`` returns: a ``ReducerOutcome`` (the state mutation to apply, or ``ReducerOutcome/unchanged``) paired with a `Reader<PostReducerContext, Effect>` (the effect to run afterward). The ``Store`` applies the mutation in phase 2 and resolves the effect, against post-mutation state, in phase 3.

### Building one

- ``reduce(_:)`` — a pure state mutation, no effect.
- `produce { ctx in … }` — an effect, no mutation.
- chain them — `.reduce { … }.react { ctx in … }` — for both.
- ``doNothing`` — neither (the monoid identity); the ``Store`` fires no notifications for it.

### The algebra — a product monoid

`Consequence` is a `Monoid`: ``combine(_:_:)`` composes componentwise — the ``ReducerOutcome`` mutations fold **sequentially**, the effect `Reader`s merge in **parallel** — with ``doNothing`` as the identity. This product structure is exactly why composing ``Behavior``s composes *both* their state changes and their effects in a single value. See <doc:Algebra>.

## Topics

### Building a Consequence

- ``reduce(_:)``
- ``doNothing``

## See Also

- ``Behavior``
- ``ReducerOutcome``
- ``Effect``
- ``PostReducerContext``
- <doc:Algebra>
