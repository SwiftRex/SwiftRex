# Channels

A `Channel` is the unit a `supervise` keeps alive — a long-lived, keyed resource the engine opens, reconciles, and tears down for you.

## Overview

Where an ``Effect`` is a one-shot you fire, a ``Channel`` is a *resource you declare*: a socket, a location stream, a poll, a timer. You describe how to open it and how to close it; the ``Store``'s engine decides *when*, by diffing the desired set your ``Keep`` returns each cycle against what is already running.

```swift
Channel(id: "socket") { dispatch in
    let s = openSocket()
    s.onMessage { dispatch(.received($0)) }                       // events out → actions
    return ChannelHandler(receive: { s.write($0) },              // values in → the resource
                          cancel:  { s.close() })                // teardown, written once
}
```

The `id` is the registry key. It lives in a **global, type-aware namespace** shared with action-driven effects, so a `produce` can ``Effect/broadcast(_:channel:file:function:line:)`` into a channel a `supervise` owns, purely by matching the id. Cross-feature id collisions are yours to prevent (use distinct id enums) — exactly as for keyed effects.

### Opening: the body and the handler

The body runs **once**, when the engine first sees the channel in the desired set. It receives `dispatch` — events the resource produces flow back out as actions — and returns a ``ChannelHandler``:

- ``ChannelHandler/receive`` — how to feed a value *into* the live resource (`socket.write`). Called for each value piped in (see Broadcasting below).
- ``ChannelHandler/cancel`` — how to tear it down (`socket.close`). Called **exactly once**, when the channel leaves the desired set or the Store deallocates. You never call it yourself.

For a **pure receiver** — a location stream, server-sent events, a timer — there is nothing to pipe in. Use ``ChannelHandler/cancelOnly(_:)`` (its `Value` is `Never`):

```swift
Channel(id: "location") { dispatch in
    let mgr = startLocationUpdates(); mgr.onUpdate { dispatch(.located($0)) }
    return .cancelOnly { mgr.stop() }
}
```

> The channel body is the *side-effecting boundary* — the one place imperative resource code (open a socket, start a `Task`, subscribe to a publisher) is expected. Keep the rest of your feature pure; let the body own the mess and the `cancel` clean it up.

### Lifetime — when to recreate

``Channel/Lifetime`` controls what a *change in state* does to a running channel:

- ``Channel/Lifetime/permanent`` (default) — open once and keep it open across state changes. Cancelled only when it leaves the desired set entirely.
- `Channel.Lifetime.ephemeral(resetKey:settle:)` — **recreate** (cancel + reopen) whenever `resetKey` changes between reconcile cycles. A search keyed to the query, a socket keyed to a room id, a poll keyed to a filter.

```swift
// Reconnect the socket whenever the room changes; keep it otherwise.
Channel(id: "room", lifetime: .ephemeral(resetKey: state.roomID)) { dispatch in … }
```

`resetKey` accepts any `Hashable & Sendable`.

#### `settle` — debounce the recreation

By default a `resetKey` change recreates the channel immediately. Pass `settle:` to **debounce the creation**: the live instance is torn down *now*, but the replacement opens only once the key has been quiet for that long — search-as-you-type reconnection without thrashing.

```swift
// Type "h","he","hel" fast → nothing opens; quiet for 300ms → one fetch for "hel".
// Change again → tear the stale fetch down immediately, debounce the next.
Channel(id: "search", lifetime: .ephemeral(resetKey: state.query, settle: .milliseconds(300))) { dispatch in … }
```

`settle` paces *creation* only; it is independent of how the channel's *values* are paced (see Delivery, below).

### Broadcasting — auto-publishing state into the channel

``Broadcasting`` lets a channel pull a value *out of state* and deliver it, deduped:

- ``Broadcasting/nothing`` (default) — open without delivering. The channel is fed, if at all, by action-driven ``Effect/broadcast(_:channel:file:function:line:)``.
- ``Broadcasting/onChange(_:)`` — deliver the value to ``ChannelHandler/receive`` on open **and** whenever it changes. Identical consecutive values are **not** re-sent (idempotent, so it survives redelivery and time-travel).

```swift
// Continuously publish the cursor position into the channel as it moves.
Channel(id: "cursor", broadcasting: .onChange(state.cursor)) { dispatch in … }
```

Use `.onChange` for a *state-derived* value that should track state. Use the action-driven ``Effect/broadcast(_:channel:file:function:line:)`` for *discrete, possibly-repeated* sends (sending `"hi"` twice must send it twice) — that path is **not** deduped.

### Delivery — the channel as a throttled subject

``ChannelDelivery`` paces the *values* flowing into a live channel (whether from `.onChange` or `.broadcast`) — the channel behaving like a `PassthroughSubject`/`CurrentValueSubject` with a `.throttle` attached:

- ``ChannelDelivery/immediate`` (default) — deliver every value as it arrives.
- ``ChannelDelivery/throttle(_:)`` — at most once per interval; values inside the window are dropped.
- ``ChannelDelivery/debounce(_:)`` — only after the values go quiet, so a burst collapses to its latest.

```swift
// Location updates flood in; cap the actions to ≤1/sec — without reconnecting the stream.
Channel(id: "location", delivery: .throttle(.seconds(1))) { dispatch in … }
```

Only the cases that need *coordination across emissions* are built in. A per-value **delay** (time-shift each event by a fixed amount) is deliberately left out — it's trivial to do in the channel body with the injected clock, so it's a story you build, not a knob: see <doc:ExampleDelay>.

**Delivery is decoupled from creation.** The channel always **opens immediately** when it enters the desired set — pacing never defers the subscription, only the values. A ``Broadcasting/onChange(_:)`` channel (a CurrentValueSubject) delivers its current value on open and paces the changes after; a ``Broadcasting/nothing`` channel (a PassthroughSubject) opens silently and its **first** broadcast goes straight through, with pacing starting only after. Because delivery state is per-instance, an `ephemeral` recreate also resets the throttle/debounce window. `settle` (creation) and `delivery` (values) are orthogonal — an ephemeral chat socket can `settle` its room-switches *and* `throttle` its inbound messages.

> Already throttling upstream (a publisher's own `.throttle`)? Don't also set `delivery:` — double-pacing behaves exactly like two `.throttle`s in one pipeline. The channel knob is for the non-reactive `.broadcast` path; the `asChannel` bridges leave value pacing to the publisher.

### The two send paths, side by side

| | Owns lifetime? | Deduped? | Cause |
|---|---|---|---|
| ``Broadcasting/onChange(_:)`` | yes (it's the channel) | yes | state changes |
| ``Effect/broadcast(_:channel:file:function:line:)`` | no — targets a live channel by id | no | an action |

A `broadcast` into an id with nothing live is simply dropped — keep the channel alive (via `supervise`, or an imperative ``Effect/open(_:)``) for the value to land.

### Action-driven lifetime (the imperative escape hatch)

Most channels are declared in a `supervise` and reconciled from state. When you instead want *you* to own the lifetime — open on `.connect`, close on `.disconnect` — drive it from `produce`:

- ``Effect/open(_:)`` — open a ``Channel`` now.
- ``Effect/cancel(id:)`` — cancel whatever runs under `id` (a channel or any keyed effect).
- ``Effect/broadcast(_:channel:file:function:line:)`` — send into it.

Both worlds share the same registry, so a socket opened imperatively still receives `broadcast`s, and a `supervise`-owned socket can still be `cancel`led by id. Prefer `supervise` — it can't leak (no state implying it ⇒ no channel) — and reach for the imperative path only when the lifetime genuinely isn't a function of state.

### From a reactive source

You rarely hand-write a channel body for a stream you already have as a publisher or async sequence. The companion bridges turn one into a `Channel` directly, mapping each emission to an action — the `asChannel` counterpart of `asEffect`:

- **`SwiftRex.Combine`** — `publisher.asChannel(id:lifetime:_:)`
- **`SwiftRex.SwiftConcurrency`** — `asyncSequence.asChannel(id:lifetime:_:)`
- **`SwiftRex.RxSwift`** · **`SwiftRex.ReactiveSwift`** · **`SwiftRex.ReactiveConcurrency`** — the same on `Infallible`/`Observable`, `SignalProducer`, and `Publisher`.

```swift
.supervise { state in
    Supervision { env in
        guard state.isTracking else { return [] }
        return [env.locationUpdates.asChannel(id: "location", AppAction.located)]
    }
}
```

These bridges are *output-only* (a publisher emits, it does not receive), so the channel is a pure receiver. **Timing:** a source that emits *synchronously on subscription* — a `CurrentValueSubject`, a `BehaviorSubject`, a ReactiveSwift `Property` — emits *inside* the channel body, before the engine has registered the channel. That is safe: every action a channel dispatches hops through the ``Store``'s send onto a later run-loop turn, so the value is **deferred** — never lost, never doubled, and never re-entering the reconcile that opened the channel. For the *send* direction (push values *into* a live channel) use ``Effect/broadcast(_:channel:file:function:line:)`` instead.

### Reconcile is idempotent

Because the desired set is recomputed from state every cycle, the same channel id may legitimately be produced more than once in one pass — e.g. a `liftEach` and a `liftCollection` over one collection both keeping element 1's `"socket"`. The engine **dedups by id** (identical entries register once, distinct inner ids all survive), so threading `supervise` through every lift never double-opens.

## Topics

### Worked Examples

- <doc:ExampleTimer>
- <doc:ExamplePolling>
- <doc:ExampleChatRoom>
- <doc:ExampleWebSocket>
- <doc:ExampleDelay>

### The Types

- ``Channel``
- ``Channel/Lifetime``
- ``Broadcasting``
- ``ChannelDelivery``
- ``ChannelHandler``
- ``Keep``

### Effect Entry Points

- ``Effect/broadcast(_:channel:file:function:line:)``
- ``Effect/open(_:)``
- ``Effect/cancel(id:)``
- ``Effect/channel(value:scheduling:file:function:line:_:)``

## See Also

- <doc:StateDrivenEffects>
- `supervise`
- `supervise`
