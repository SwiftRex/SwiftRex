# Adding Effects

Reach the outside world — and fold the result back in as an action.

## Overview

The counter in <doc:BuildYourFirstFeature> was pure. Real features talk to networks, clocks, and databases. In SwiftRex that work lives in exactly one place: an ``Effect`` returned by a ``Behavior``. The behavior stays pure — it *describes* the effect — and the ``Store`` runs it, looping the outcome back as another action. Dependencies arrive through the feature's `Environment`, never as singletons. Every snippet here compiles against the current API.

## Step 1 — Declare the dependency

The `Environment` is whatever the feature needs from the outside. Model it as a value of injectable functions, so tests pass a fake and production passes the real thing.

```swift
import SwiftRex
import SwiftRexSwiftConcurrency   // async/await → Effect bridges

struct API: Sendable {
    var fetch: @Sendable (Int) async throws -> String
}
```

## Step 2 — Make the result an action

The async call can succeed or fail; carry that back in as a `Result` case so the reducer remains deterministic.

```swift
enum LoaderAction: Sendable {
    case load(Int)
    case didLoad(Result<String, Error>)
}

struct LoaderState: Equatable, Sendable {
    var value = ""
    var isLoading = false
}
```

## Step 3 — Reduce, then react

On `.load`, flip a flag (`reduce`) **and** kick off the effect (`react`). `Effect.throwingTask` runs an `async throws` closure and maps its `Result` straight onto your action case — `LoaderAction.didLoad` *is* the transform. When the result arrives as `.didLoad`, just reduce.

```swift
let loaderBehavior = Behavior<LoaderAction, LoaderState, API>.handle { action, _ in
    switch action {
    case .load(let id):
        .reduce { $0.isLoading = true }
            .react { ctx in
                Effect.throwingTask(LoaderAction.didLoad) {
                    try await ctx.environment.fetch(id)
                }
            }
    case .didLoad(let result):
        .reduce {
            $0.isLoading = false
            if case .success(let value) = result { $0.value = value }
        }
    }
}
```

The effect closure receives a ``PostReducerContext`` — `ctx.environment` is the injected `API`, and the effect resolves against post-mutation state.

## Step 4 — Inject and run

```swift
@MainActor
func runLoader() {
    let live = API(fetch: { id in /* URLSession … */ "item \(id)" })
    let store = Store(initial: LoaderState(), behavior: loaderBehavior, environment: live)

    let token = store.observe(didChange: { print(store.state) })
    store.dispatch(.load(42))   // isLoading = true → … → value = "item 42", isLoading = false
    _ = token
}
```

In a test you'd pass an `API` whose `fetch` returns a fixture, and drive the whole sequence deterministically with `TestStore` from `SwiftRex.Testing`.

> This is an **action-driven** effect: `.load` causes one fetch that finishes. When an effect's lifetime is implied by *state* instead — a socket open while a room is joined, a timer ticking while a screen shows, a poll running while a query is set — reach for the state-driven `supervise` axis instead. See <doc:StateDrivenEffects>.

## Why this shape

- **Determinism** — the reducer only ever sees values (the action), never performs the call, so it's pure and trivially testable.
- **Visibility** — the request *and* its result are actions, so they show up in the action log with their ``ActionSource`` provenance. Nothing happens "invisibly" inside an effect.
- **Control** — attach an ``EffectScheduling`` (`.scheduling(.debounce(id:delay:))`, `.throttle`, `.cancelInFlight`) to coordinate in-flight work; the ``Store`` owns the bookkeeping.

## See Also

- ``Effect``
- ``EffectScheduling``
- ``Behavior``
- ``Consequence``
- <doc:StateDrivenEffects>
- <doc:BuildYourFirstFeature>
- <doc:Algebra>
