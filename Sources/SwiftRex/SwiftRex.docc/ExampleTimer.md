# Example: a Timer

A ticking clock that runs while the screen says it should — and recreates itself when the interval changes. The smallest useful `supervise`.

## Overview

A timer is the canonical state-driven effect: nothing *triggers* a tick, the timer simply *exists* while `isRunning` is true. Stop it by leaving that state, not by cancelling an effect.

```swift
import SwiftRex

enum TimerAction: Sendable {
    case start, stop
    case setInterval(Duration)
    case tick
}

struct TimerState: Sendable {
    var isRunning = false
    var interval: Duration = .seconds(1)
    var elapsed = 0
}

let timer = Behavior<TimerAction, TimerState, Void>
    .reduce { action, state in
        switch action {
        case .start: state.isRunning = true
        case .stop: state.isRunning = false
        case .setInterval(let d): state.interval = d
        case .tick: state.elapsed += 1
        }
    }
    .supervise { state in
        Keep { _ in
            guard state.isRunning else { return [] }            // stopped → the ticker is cancelled
            return [Channel(id: "ticker", lifetime: .ephemeral(resetKey: state.interval)) { dispatch in
                let task = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: state.interval)
                        dispatch(.tick)
                    }
                }
                return .cancelOnly { task.cancel() }
            }]
        }
    }
```

### What each piece does

- **`.start` / `.stop` flip a flag** — they don't touch the timer directly. `supervise` reads `isRunning` and the engine opens or closes the channel to match. Dispatch `.stop` and the `Keep` returns `[]`; the engine cancels the channel and `task.cancel()` runs. You never wired teardown to `.stop`.
- **`.ephemeral(resetKey: state.interval)`** — while running, changing the interval *recreates* the channel: the old `Task` is cancelled and the body re-runs with the new period. A ``Channel/Lifetime/permanent`` ticker would keep the stale interval; the reset key is what makes "change the speed" work without a manual stop/start.
- **`.cancelOnly`** — the ticker only emits (`dispatch(.tick)`); nothing is ever piped *in*, so its ``ChannelHandler`` is `cancelOnly`. The body's `Task` is the side-effecting boundary; `cancel` tears it down exactly once.

### Make it testable — inject the clock

`Task.sleep` reads the wall clock, which a test can't control. Move the clock into the environment and a `TestClock` makes ticks deterministic:

```swift
struct TimerEnv: Sendable { let clock: any Clock<Duration> }

// in supervise:
return [Channel(id: "ticker", lifetime: .ephemeral(resetKey: state.interval)) { dispatch in
    let task = Task {
        while !Task.isCancelled {
            try? await env.clock.sleep(for: state.interval)
            dispatch(.tick)
        }
    }
    return .cancelOnly { task.cancel() }
}]
```

Now `Keep { env in … }` reads `env.clock`; pass an `ImmediateClock` or `TestClock` in tests and a `ContinuousClock` in production. The `Store` already runs the effect engine on an injected clock — see ``Store``.

## See Also

- <doc:StateDrivenEffects>
- <doc:Channels>
- <doc:ExamplePolling>
- ``Channel/Lifetime``
- `supervise`
