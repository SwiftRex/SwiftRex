# Example: Delaying Emissions

Time-shift every event by a fixed amount — the one pacing the framework deliberately *doesn't* build in, because you can do it in the channel body in a few lines.

## Overview

``ChannelDelivery`` offers ``ChannelDelivery/throttle(_:)`` and ``ChannelDelivery/debounce(_:)`` — the cases that need *stateful coordination across emissions* (a shared window, a restartable timer) the engine is best placed to own. It deliberately omits a per-value **delay** (RxSwift's `.delay`: shift each event by a fixed amount, preserving their spacing — events at 4s, 6s, 9s surface at 5s, 7s, 10s with a 1s delay). A framework-level delay would need one independent timer per in-flight value plus their teardown, for a behaviour you can express trivially yourself: sleep on the injected clock before dispatching.

So `delay` is a *story*, like ``ExampleTimer`` and ``ExamplePolling`` — a pattern you build, not a helper you call.

```swift
import SwiftRex

struct Event: Sendable, Equatable { … }

struct FeedEnv: Sendable {
    let events: AsyncStream<Event>
    let clock: any Clock<Duration>
    let lag: Duration
}

enum FeedAction: Sendable {
    case listen, stop
    case surfaced(Event)
}

struct FeedState: Sendable {
    var listening = false
    var shown: [Event] = []
}

let feed = Behavior<FeedAction, FeedState, FeedEnv>
    .reduce { action, state in
        switch action {
        case .listen: state.listening = true
        case .stop: state.listening = false
        case .surfaced(let e): state.shown.append(e)
        }
    }
    .supervise { state in
        Supervision { env in
            guard state.listening else { return [] }
            return [
                Channel(id: "feed") { dispatch in
                    let task = Task {
                        await withTaskGroup(of: Void.self) { group in
                            for await event in env.events {
                                group.addTask {
                                    try? await env.clock.sleep(for: env.lag)   // shift this event by `lag`
                                    dispatch(.surfaced(event))
                                }
                            }
                        }
                    }
                    return .cancelOnly { task.cancel() }
                }
            ]
        }
    }
```

### Why this is the right shape

- **Each event gets its own timer**, so the lag is applied *independently* and the original spacing is preserved — a true time-shift, not a debounce-style collapse. Events at 4s/6s/9s surface at 5s/7s/10s.
- **`withTaskGroup` makes cancellation free.** `task.cancel()` cancels the iterating loop **and** every pending `clock.sleep` in the group, so when the channel leaves the desired set no delayed action fires after teardown. That structured-concurrency teardown is exactly the per-channel bookkeeping a generic `ChannelDelivery.delay` would have to manage for *every* channel — cheap here, costly there.
- **The clock is injected**, so a `TestClock` makes the lag deterministic; advancing the clock surfaces the events exactly `lag` later.

### When you'd reach for the built-in pacing instead

Use ``ChannelDelivery/throttle(_:)`` / ``ChannelDelivery/debounce(_:)`` when you want to *drop* or *coalesce* values across a shared window — that needs cross-emission state the engine coordinates for you. Reach for this hand-rolled delay when you want to *keep every value* but shift it in time. The framework supplies the part that needs coordination; you supply the part that doesn't.

## See Also

- <doc:StateDrivenEffects>
- <doc:Channels>
- <doc:ExampleTimer>
- <doc:ExamplePolling>
- ``ChannelDelivery``
