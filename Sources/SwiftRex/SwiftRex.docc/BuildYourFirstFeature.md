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

A ``Behavior`` maps each action to a ``Consequence``. Here every action is a pure state change, so each returns ``Consequence/reduce(_:)``. (`Void` is the environment — this feature has no dependencies yet.)

```swift
let counterBehavior = Behavior<CounterAction, CounterState, Void>.handle { action, _ in
    switch action {
    case .increment: .reduce { $0.count += 1 }
    case .decrement: .reduce { $0.count -= 1 }
    case .reset:     .reduce { $0.count = 0 }
    }
}
```

## Step 4 — Create the store and drive it

The ``Store`` is the only thing that runs. Create one with the initial state and the behavior, then dispatch actions and observe changes. ``StoreType/observe(didChange:)`` returns a ``SubscriptionToken`` you must **retain** — when it's released, the observation stops.

```swift
@MainActor
func runCounter() {
    let store = Store(initial: CounterState(), behavior: counterBehavior)

    let token = store.observe(didChange: { print("count =", store.state.count) })

    store.dispatch(.increment)   // count = 1
    store.dispatch(.increment)   // count = 2
    store.dispatch(.reset)       // count = 0

    _ = token                    // keep the observer alive
}
```

That's a fully working feature — no UI required, and trivially testable with `TestStore` from `SwiftRex.Testing`.

## Step 5 — Put it on screen

Add `SwiftRex.SwiftUI` and turn the store into an `ObservableObject` with `asObservableObject()`. The view reads ``StoreType/state`` and sends actions with ``StoreType/dispatch(_:source:)``.

```swift
import SwiftUI
import SwiftRexSwiftUI

struct CounterView: View {
    @ObservedObject var store: ObservableObjectStore<CounterAction, CounterState>

    var body: some View {
        VStack(spacing: 16) {
            Text("\(store.state.count)").font(.largeTitle)
            HStack {
                Button("–") { store.dispatch(.decrement) }
                Button("Reset") { store.dispatch(.reset) }
                Button("+") { store.dispatch(.increment) }
            }
        }
    }
}

#Preview {
    let store = Store(initial: CounterState(), behavior: counterBehavior)
    return CounterView(store: store.asObservableObject())
}
```

`withAnimation { store.dispatch(.increment) }` works too — the `Store` is `@MainActor`, so the change lands in the right SwiftUI transaction.

## Where to go next

- **Side effects** — return an ``Effect`` from the behavior (`.reduce { … }.react { ctx in … }`) to call a network or a clock, feeding the result back as another action. Inject what the effect needs through the `Environment` instead of `Void`.
- **Scaling up** — once you have more than one feature, lift each into the app and compose them: <doc:Lifting> and <doc:Modularisation>.
- **The model behind it** — <doc:Algebra> explains why all of this composes.

## See Also

- ``Behavior``
- ``Store``
- ``Consequence``
- <doc:StateAndActions>
- <doc:Lifting>
