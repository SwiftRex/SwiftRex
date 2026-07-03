# Modularisation & Features

Build each feature as its own small framework, in isolation — then lift them all into one app.

## Overview

SwiftRex is designed so a feature never has to know about the app that hosts it. You build each feature as a **small, self-contained module** — its own Swift package or target that depends on `SwiftRex` and *nothing about the app* — with its own local `Action`, `State`, `Environment`, and a ``Behavior`` (and, optionally, its own SwiftUI view). The app then **lifts** each feature up to global types and combines them.

Why it's worth the discipline:

- **Independent builds** — a feature compiles on its own; changing one doesn't rebuild the world.
- **Focused tests** — the pure layers (``Reducer``, ``Behavior``) test with values in, values out: no app, no mocks. Drive whole use-cases with `TestStore` from `SwiftRex.Testing`.
- **Isolated previews** — a feature renders in a SwiftUI preview (or a tiny harness app) without launching the full product.
- **Reuse** — the same feature module drops into more than one app.

## A feature, in one module

A feature is just the SwiftRex pieces at *local* types:

```swift
// In the Counter feature package — knows nothing about AppAction/AppState.
public enum CounterAction { case increment, decrement, reset }
public struct CounterState: Equatable { public var count = 0 }
public struct CounterEnvironment { public var analytics: Analytics }

public let counterBehavior = Behavior<CounterAction, CounterState, CounterEnvironment> { action, _ in
    switch action {
    case .increment: .reduce { $0.count += 1 }
    case .decrement: .reduce { $0.count -= 1 }
    case .reset:     .reduce { $0.count = 0 }
    }
}
```

Its SwiftUI view renders from a ``StoreProjection`` of that slice, so the view, too, only knows the local types.

## Wiring features into the app

The app owns the global `AppAction` / `AppState` / `AppEnvironment` and assembles the features by **lifting** each one (see <doc:Lifting>) and combining:

```swift
let appBehavior = Behavior.combine(
    counterBehavior.lift(action: \.counter, state: \.counter, environment: \.counterEnv),
    searchBehavior.lift(action: \.search,  state: \.search,  environment: \.searchEnv),
    todoBehavior.liftCollection(action: \.todo, stateContainer: \.todos)
)
let store = Store(initial: .init(), behavior: appBehavior, environment: appEnv)
```

Crossing the **environment** boundary is the same idea applied to dependencies: a feature that doesn't know the app's environment type exports a factory — `(CounterEnvironment) -> Behavior<…>` or simply takes its `Environment` generic — and the app projects its own environment down (`\.counterEnv`) when it lifts. Features talk to each other only through **actions**, never by reaching into each other's state.

## The opinionated layer: `SwiftRex.Architecture`

`SwiftRex.Architecture` packages this pattern so a feature is a single `enum` namespace. The `@Feature(_:)` macro takes a `FeatureRole` — `.publicEntryPoint` for a module's public entry, `.internalScreen` for a screen composed inside it — and generates `initialState(with:)` plus `view(store:environment:) -> some View`. The generated `view` builds a view store from an environment-aware projection (both `mapState` and `mapAction` are `Reader<Environment, …>`, so the view can format and parse with live dependencies) and hands it to the feature's `Content`. The store is a coarse `ViewStore` — or a field-level `TrackedViewStore` when the nested `ViewState` is `@Tracked`; either way the view reads `viewStore.state.field`. The concrete `ViewState`/`ViewAction`/`Content` stay `internal` and never cross the module boundary — only `State`/`Action`/`Environment`/`Input` (which you lift with the core `lift(...)`) and the opaque `view` are public. The app composes each feature's `behavior()` with `lift` and renders it with `view(store:environment:)`.

## See Also

- ``Behavior``
- ``Store``
- ``StoreProjection``
- ``ElementAction``
- <doc:Lifting>
- <doc:Algebra>
