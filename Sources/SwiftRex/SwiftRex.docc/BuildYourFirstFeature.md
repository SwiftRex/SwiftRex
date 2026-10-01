# Build Your First Feature

A complete, compiling counter — from state to a SwiftUI screen — in a few small steps.

## Overview

This walkthrough builds a tiny but complete feature with the core `SwiftRex` package (and, for the screen, `SwiftRex.SwiftUI`). Every snippet compiles against the current API — paste them into a file, import `SwiftRex`, and follow along. By the end you'll have a counter you can drive from code and render in SwiftUI.

## Step 1 — Model the state

State is a value type — the feature's single source of truth.

```swift
import SwiftRex

struct CounterState: Equatable, Sendable {
    var count = 0
}
```

## Step 2 — Enumerate the actions

Actions are *events* that can happen to the feature.

```swift
enum CounterAction: Sendable {
    case increment
    case decrement
    case reset
}
```

## Step 3 — Write the behavior

A ``Behavior`` maps each action to a ``Reaction`` — a state change (`reduce`), an effect (`produce`), or both. Here every action is a pure state change, so each returns `reduce`. (`Void` is the environment — this feature has no dependencies yet.)

```swift
let counterBehavior = Behavior<CounterAction, CounterState, Void>.handle { action, _ in
    switch action {
    case .increment: .reduce { $0.count += 1 }
    case .decrement: .reduce { $0.count -= 1 }
    case .reset: .reduce { $0.count = 0 }
    }
}
```

## Step 4 — Create the store and drive it

The ``Store`` is the only thing that runs. Create one with the initial state and the behavior, then dispatch actions and follow its state. A store can't be read, only followed: ``StateStream/observe(_:)`` on its ``StoreType/stateStream`` delivers the current state right away, then every new one, and returns a ``UISubscriptionToken`` you must **retain** — when it's released, delivery stops.

```swift
@MainActor
func runCounter() {
    let store = Store(initial: CounterState(), behavior: counterBehavior)

    let token = store.stateStream.observe { print("count =", $0.count) } // count = 0

    store.dispatch(.increment) // count = 1
    store.dispatch(.increment) // count = 2
    store.dispatch(.reset) // count = 0

    _ = token // keep the observer alive
}
```

That's a fully working feature — no UI required, and trivially testable with `TestStore` from `SwiftRex.Testing`.

## Step 5 — Put it on screen

Add `SwiftRex.SwiftUI`. The `App` keeps the real ``Store`` as a plain `let` — it's never observed, only dispatched to and handed down. The root view **makes** a view store from it (`store.viewStore()`, always explicit) and **keeps** it with `@OwnedStore`; every view below it **receives** that `ViewStore` as a plain `let`. That's the whole rule — on every OS and under every observation strategy. Reads go through `viewStore.state` and are granular: `viewStore.state.count` makes the view depend on `count` alone. Actions go out with `dispatch`.

```swift
import SwiftUI
import SwiftRexSwiftUI

@main
struct CounterApp: App {
    let store = Store(initial: CounterState(), behavior: counterBehavior) // the real store: never observed

    var body: some Scene {
        WindowGroup { RootView(store: store) }
    }
}

struct RootView: View {
    @OwnedStore var viewStore: ViewStore<CounterAction, CounterState> // kept here: made once, however often RootView is re-created

    init(store: some StoreType<CounterAction, CounterState>) {
        _viewStore = OwnedStore(wrappedValue: store.viewStore())
    }

    var body: some View { CounterView(viewStore: viewStore) }
}

struct CounterView: View {
    let viewStore: ViewStore<CounterAction, CounterState> // a receiver — the same view store, never a new one

    var body: some View {
        VStack(spacing: 16) {
            Text("\(viewStore.state.count)").font(.largeTitle)
            HStack {
                Button("–") { viewStore.dispatch(.decrement) }
                Button("Reset") { viewStore.dispatch(.reset) }
                Button("+") { viewStore.dispatch(.increment) }
            }
        }
    }
}

#Preview { RootView(store: Store(initial: CounterState(), behavior: counterBehavior)) }
```

`@OwnedStore`'s initial value is lazy (like `@StateObject`'s): `store.viewStore()` runs the first time the view appears, not on every re-initialisation, so the view store's snapshot and its record of what each view read survive parent re-renders. Never call `.viewStore()` bare in a `body` — that would make a new one every render. By default the view store signals SwiftUI through the Observation framework on iOS 17+ and through Combine below — the `ViewStore` receivers work the same either way. Force Combine where the view store is made: `store.viewStore(.combine)`.

`withAnimation { viewStore.dispatch(.increment) }` works too — dispatch reaches the view store synchronously on the main actor, so the change lands in the right SwiftUI transaction.

## Where to go next

- **Side effects** — return an ``Effect`` from the behavior (`.reduce { … }.produce { ctx in … }`) to call a network or a clock, feeding the result back as another action. Inject what the effect needs through the `Environment` instead of `Void`: <doc:AddingEffects>.
- **Less wiring** — the `@Feature` macro co-locates state, actions, behavior, and screen in one `enum` and generates the view-store plumbing this walkthrough did by hand (its `view(store:environment:)` keeps the view store for you). It's the recommended structure for real apps: <doc:Features>.
- **Scaling up** — once you have more than one feature, lift each into the app and compose them: <doc:Lifting> and <doc:Modularisation>.
- **The model behind it** — <doc:Algebra> explains why all of this composes.

## See Also

- ``Behavior``
- ``Store``
- ``Reaction``
- ``Consequence``
- <doc:StateAndActions>
- <doc:Lifting>
