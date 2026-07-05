# ``SwiftRex``

Unidirectional dataflow as a small, lawful algebra — pure values you compose, run by a single interpreter.

## Overview

SwiftRex models your whole app as one loop of pure values:

- An **action** describes something that happened.
- A ``Behavior`` is a monoid of ``Consequence``s — each a **reaction** to an action (a ``Reaction``: `reduce` the state and/or `produce` an effect) or a **supervision** of state (a ``Supervision``: the channels to `keep` alive).
- The ``Store`` is the **only** thing that runs: a behavior only *describes* — `reduce`/`produce`/`supervise` — and the Store **mutates**, **performs**, and **keeps**. It notifies observers exactly once per change; actions an effect produces loop back through the same path.

Effects come in two flavours: *action-driven* — a `produce` that runs because something happened (Elm's `Cmd`) — and *state-driven* — a `supervise` that keeps a long-lived resource (a socket, a timer, a poll) alive for exactly as long as the state implies it (Elm's `Sub`). See <doc:StateDrivenEffects>.

Everything except the `Store` is inert and composable. Two `Reducer`s combine into a `Reducer`; two `Behavior`s into a `Behavior`; an `Effect` merges with another `Effect`. That "compose two, get one of the same kind, with a do-nothing identity" shape is a **monoid**, and it's the whole story — see <doc:Algebra>.

> New here? Start with the [README](https://github.com/SwiftRex/SwiftRex#readme) for installation and worked examples, then come back for the type-by-type reference below.

## Companion Products

`SwiftRex` is the core. These ship as separate products (each its own import); the third-party bridges are opt-in via package traits:

- **`SwiftRex.SwiftConcurrency`** — `async`/`await` effect bridges (`Task`, `AsyncSequence`), `asChannel` for long-lived subscriptions, `store.stream`.
- **`SwiftRex.Combine`** — `asEffect()` / `asChannel()` on `Publisher`, `store.publisher`, `ctx.readLiveState()`.
- **`SwiftRex.RxSwift`** · **`SwiftRex.ReactiveSwift`** · **`SwiftRex.ReactiveConcurrency`** — the same `asEffect` / `asChannel` bridge surface for each reactive runtime *(each behind a trait of the same name)*.
- **`SwiftRex.SwiftUI`** — `ViewStore` (coarse) and `TrackedViewStore` (field-level, via `@Tracked`) for `@Observable`; `asObservableObject()` for the Combine `ObservableObject` path.
- **`SwiftRex.Architecture`** — the opinionated `@Feature` module pattern.
- **`SwiftRex.Operators`** — symbolic operators (`<>`, `|>`, …) for the types above.
- **`SwiftRex.Testing`** — `TestStore` for deterministic, exhaustive unit tests.

## Topics

### Start Here

- <doc:BuildYourFirstFeature>
- <doc:AddingEffects>
- <doc:Features>
- <doc:Navigation>

### Concepts

- <doc:StateAndActions>
- <doc:Algebra>
- <doc:Lifting>
- <doc:Modularisation>

### The Core Loop

- ``Reducer``
- ``Effect``
- ``Middleware``
- ``Behavior``
- ``Consequence``
- ``Reaction``
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
- ``ChannelHandler``
- ``SubscriptionToken``
- ``AnyHashableSendable``

### State-Driven Effects

- <doc:StateDrivenEffects>
- <doc:Channels>
- <doc:ExampleTimer>
- <doc:ExamplePolling>
- <doc:ExampleChatRoom>
- <doc:ExampleWebSocket>
- <doc:ExampleDelay>
- ``Channel``
- ``ChannelDelivery``
- ``Supervision``
- ``Keep``

### Composition

- ``ReducerBuilder``
