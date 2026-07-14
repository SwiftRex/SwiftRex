# ``SwiftRex``

Unidirectional dataflow for Swift — one `Store` runs your app; everything else is a pure value you compose.

## Overview

SwiftRex models your whole app as one loop:

- An **action** — a plain value — describes something that happened: a tap, a response, a tick.
- A ``Behavior`` describes how a feature responds, one fluent builder per concern:

```swift
let feature = Behavior<Action, State, Environment>
    .reduce { action, state in … }      // the Reducer — reduces actions into state
    .produce { action, ctx in … }       // the Effect Producer — produces effects from actions
    .supervise { state in … }           // the Effect Supervisor — supervises effects for a given state
```

- The ``Store`` is the **only** thing that runs: a behavior only *describes* — the Store **maintains** state (via `reduce`), **performs** the effects a `produce` yields, and **supervises** the channels a `supervise` keeps. It notifies observers exactly once per change; actions an effect dispatches loop back through the same path.

Effects come in two flavours: *action-driven* — an **Effect Producer** (`produce`) that runs because something happened — and *state-driven* — an **Effect Supervisor** (`supervise`) that keeps a long-lived resource (a socket, a timer, a poll) alive for exactly as long as the state implies it. See <doc:StateDrivenEffects>.

Everything except the `Store` is inert and composable. Two `Behavior`s combine into one with `<>`; features written against their own local types **lift** to the app's global types before composing (<doc:Lifting>); the ``SwiftRex/Behavior`` page shows the fluent surface in full. That "compose two, get one of the same kind, with a do-nothing identity" shape is a **monoid** — when you want the lawful underpinnings behind the whole design, see <doc:Algebra>.

> New here? Start with the [README](https://github.com/SwiftRex/SwiftRex#readme) for the pragmatic tour — a feature in one screen, installation, producer-vs-supervisor effects, modularity — then <doc:BuildYourFirstFeature>, and come back for the type-by-type reference below.

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

- <doc:Installation>
- <doc:BuildYourFirstFeature>
- <doc:AddingEffects>
- <doc:Features>
- <doc:Navigation>
- <doc:NavigationEndToEnd>

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
