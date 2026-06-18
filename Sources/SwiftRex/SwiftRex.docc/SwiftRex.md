# ``SwiftRex``

Unidirectional dataflow as a small, lawful algebra — pure values you compose, run by a single interpreter.

## Overview

SwiftRex models your whole app as one loop of pure values:

- An **action** describes something that happened.
- A ``Behavior`` (a ``Reducer`` for the state change, a ``Middleware`` for the effect) maps that action to a ``Consequence`` — *what to change* (a ``ReducerOutcome``) and *what to do next* (an ``Effect``).
- The ``Store`` is the **only** thing that runs: it applies the mutation, notifies observers exactly once, then executes the effect. Actions the effect produces loop back through the same path.

Everything except the `Store` is inert and composable. Two `Reducer`s combine into a `Reducer`; two `Behavior`s into a `Behavior`; an `Effect` merges with another `Effect`. That "compose two, get one of the same kind, with a do-nothing identity" shape is a **monoid**, and it's the whole story — see <doc:Algebra>.

> New here? Start with the [README](https://github.com/SwiftRex/SwiftRex#readme) for installation and worked examples, then come back for the type-by-type reference below.

## Companion Products

`SwiftRex` is the core. These ship as separate products (each its own import); the third-party bridges are opt-in via package traits:

- **`SwiftRex.SwiftConcurrency`** — `async`/`await` effect bridges (`Task`, `AsyncSequence`), `store.stream`.
- **`SwiftRex.Combine`** — `asEffect()` on `Publisher`, `store.publisher`, `ctx.readLiveState()`.
- **`SwiftRex.RxSwift`** · **`SwiftRex.ReactiveSwift`** · **`SwiftRex.ReactiveConcurrency`** — the same bridge surface for each reactive runtime *(each behind a trait of the same name)*.
- **`SwiftRex.SwiftUI`** — `asObservableObject()`, the `@ViewModel` macro, `HasViewModel`.
- **`SwiftRex.Architecture`** — the opinionated `@Feature` module pattern.
- **`SwiftRex.Operators`** — symbolic operators (`<>`, `|>`, …) for the types above.
- **`SwiftRex.Testing`** — `TestStore` for deterministic, exhaustive unit tests.

## Topics

### Concepts

- <doc:Algebra>

### The Core Loop

- ``Reducer``
- ``Effect``
- ``Middleware``
- ``Behavior``
- ``Consequence``
- ``ReducerOutcome``

### Running It — the Store

- ``Store``
- ``StoreType``
- ``StoreProjection``
- ``StoreBuffer``
- ``StoreHooks``
- ``StoreReentranceInfo``

### Actions & Context

- ``ActionSource``
- ``DispatchedAction``
- ``ElementAction``
- ``PreReducerContext``
- ``PostReducerContext``

### Effects & Scheduling

- ``EffectScheduling``
- ``SubscriptionToken``
- ``AnyHashableSendable``

### Composition

- ``ReducerBuilder``
