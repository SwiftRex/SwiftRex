# Example: a WebSocket

A long-lived connection that reconnects when the auth token rotates, streams events in as actions, and pushes a state-derived presence value out — without you ever writing reconnect or teardown logic.

## Overview

Where <doc:ExampleChatRoom> sends *discrete* messages from actions, this feed pushes a *state-derived* value — your presence — and reconnects on a credential change. It shows the two ``Channel`` knobs working together: ``Channel/Lifetime`` for *when to reconnect* and ``Broadcasting`` for *what to keep publishing*.

```swift
import SwiftRex

struct Event: Sendable, Equatable { … }
enum Presence: Hashable, Sendable { case online, away, busy }

struct WebSocket: Sendable {
    let onEvent: @Sendable (@escaping @Sendable (Event) -> Void) -> Void
    let send: @Sendable (Presence) -> Void
    let close: @Sendable () -> Void
}

struct FeedEnv: Sendable { let open: @Sendable (URL, String) -> WebSocket }

enum FeedAction: Sendable {
    case event(Event)
    case setPresence(Presence)
    case rotated(token: String)
}

struct FeedState: Sendable {
    let url: URL
    var token: String
    var presence: Presence = .online
    var feed: [Event] = []
}

let feed = Behavior<FeedAction, FeedState, FeedEnv>
    .reduce { action, state in
        switch action {
        case .event(let e): state.feed.append(e)
        case .setPresence(let p): state.presence = p
        case .rotated(let token): state.token = token
        }
    }
    .supervise { state in
        Keep { env in
            [Channel(
                id: "feed",
                lifetime: .ephemeral(resetKey: state.token),        // reconnect when the token rotates
                broadcasting: .onChange(state.presence)             // publish presence on open + on change
            ) { dispatch in
                let ws = env.open(state.url, state.token)
                ws.onEvent { dispatch(.event($0)) }                 // inbound stream → actions
                return ChannelHandler(
                    receive: { presence in ws.send(presence) },     // each presence value → ws.send
                    cancel:  { ws.close() }
                )
            }]
        }
    }
```

### Lifetime vs. Broadcasting — the two diffs

The engine tracks **two identities** per channel, and they do different jobs:

- **`lifetime: .ephemeral(resetKey: state.token)`** — when the token changes, the channel is *recreated*: `ws.close()` then a fresh `env.open(url, newToken)`. The connection is rebuilt. An ``Channel/Lifetime/permanent`` channel would keep the stale connection.
- **`broadcasting: .onChange(state.presence)`** — when presence changes, the channel is *kept* and the new value is *piped in*: `receive(.away)` → `ws.send(.away)`. The socket stays open; only the value flows. Identical consecutive values are **not** re-sent (the dedup makes redelivery and time-travel safe), so `presence` must be `Hashable`.

Token change ⇒ reconnect. Presence change ⇒ push down the same wire. Two knobs, two behaviours, set declaratively from state.

### State-driven vs. action-driven publishing

Presence is *derived from state*, so ``Broadcasting/onChange(_:)`` is the right tool — it tracks state automatically and idempotently. Compare <doc:ExampleChatRoom>, where each chat message is a *discrete, possibly-repeated* event from an action and therefore uses ``Effect/broadcast(_:channel:file:function:line:)`` (not deduped). Same socket shape; different reason for sending.

### Receiving only

If a feed *only* streamed events and never sent anything out, its ``ChannelHandler`` would be ``ChannelHandler/cancelOnly(_:)`` (its `Value` is `Never`) and you'd drop the `broadcasting:` argument entirely:

```swift
Channel(id: "feed", lifetime: .ephemeral(resetKey: state.token)) { dispatch in
    let ws = env.open(state.url, state.token)
    ws.onEvent { dispatch(.event($0)) }
    return .cancelOnly { ws.close() }
}
```

## See Also

- <doc:StateDrivenEffects>
- <doc:Channels>
- <doc:ExampleChatRoom>
- ``Channel/Lifetime``
- ``Broadcasting``
