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

A ``Behavior`` maps each action to a ``Consequence``. Here every action is a pure state change, so each returns `reduce`. (`Void` is the environment — this feature has no dependencies yet.)

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

Add `SwiftRex.SwiftUI` and wrap the store with `observable()` — the store a view reads. Reads are granular: `store.count` makes the view depend on `count` alone. Actions go out with ``StoreType/dispatch(_:source:)``.

The observable store holds a snapshot and the list of what each view read, so it must be **built once** and owned by something that outlives body re-evaluations — here the `App`, which is initialised once. Views below it just receive the reference as a `let`.

```swift
import SwiftUI
import SwiftRexSwiftUI

@main struct CounterApp: App {
    // The owner: built once, when the app starts.
    @State private var store = Store(initial: CounterState(), behavior: counterBehavior).observable()

    var body: some Scene {
        WindowGroup { CounterView(store: store) }
    }
}

struct CounterView: View {
    let store: ObservableStore<CounterAction, CounterState>   // a receiver — the reference, not a new store

    var body: some View {
        VStack(spacing: 16) {
            Text("\(store.count)").font(.largeTitle)
            HStack {
                Button("–") { store.dispatch(.decrement) }
                Button("Reset") { store.dispatch(.reset) }
                Button("+") { store.dispatch(.increment) }
            }
        }
    }
}

#Preview {
    ObservableStoreHost {
        Store(initial: CounterState(), behavior: counterBehavior).observable()
    } content: { CounterView(store: $0) }
}
```

Owning it in an ordinary view instead? Use `ObservableStoreHost` (as the preview does): it builds the store once per view identity. Don't build one in a `body` (`CounterView(store: appStore.observable())`) — every re-evaluation would discard the store and subscribe a new one. And `@State` in an ordinary view keeps the first instance but still evaluates its initial value on every `init`; the host's closure runs only when there is no store yet.

Targeting iOS 13–16? Observe with `.observable(.combine)`, own it with `@StateObject` (or the host) and receive it as `@ObservedObject var store` — the body stays the same.

`withAnimation { store.dispatch(.increment) }` works too — the `Store` is `@MainActor`, so the change lands in the right SwiftUI transaction.

## Where to go next

- **Side effects** — return an ``Effect`` from the behavior (`.reduce { … }.produce { ctx in … }`) to call a network or a clock, feeding the result back as another action. Inject what the effect needs through the `Environment` instead of `Void`: <doc:AddingEffects>.
- **Less wiring** — the `@Feature` macro co-locates state, actions, behavior, and screen in one `enum` and generates the view-store plumbing this walkthrough did by hand. It's the recommended structure for real apps: <doc:Features>.
- **Scaling up** — once you have more than one feature, lift each into the app and compose them: <doc:Lifting> and <doc:Modularisation>.
- **The model behind it** — <doc:Algebra> explains why all of this composes.

## See Also

- ``Behavior``
- ``Store``
- ``Consequence``
- <doc:StateAndActions>
- <doc:Lifting>
