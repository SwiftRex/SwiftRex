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

`SwiftRex.Architecture` packages this pattern so a feature is a single namespace. The `@Feature` macro synthesizes a feature's `initialState(with:)` and conformance to the `Feature` protocol, and a `Module` co-locates a feature's `Action`/`State`/`Environment` **and** its SwiftUI `Content` view in one value — with a single `lift(...)` that raises the whole module (all three axes) to the app's global types, and `view(for:environment:)` to render it from a store (the environment feeds `mapState`, so the view can format with live dependencies). `FeatureHost` hosts a feature at the app root. It's optional sugar over the same core lifting you saw above — reach for it when you want the whole feature, view included, to travel as one liftable unit.

## See Also

- ``Behavior``
- ``Store``
- ``StoreProjection``
- ``ElementAction``
- <doc:Lifting>
- <doc:Algebra>
