# Example: a Chat Room

A full-duplex socket — `supervise` keeps it open and turns inbound messages into actions; a `produce` sends outbound messages into the same live socket. The two halves rendezvous on the channel id.

## Overview

A chat room needs both directions, and they belong to different axes:

- **Keeping the socket open** is *state-driven* — it should be alive while you're in the room. That's `supervise`.
- **Sending a message** is *action-driven* — a `.send(text)` action causes one write. That's `produce`, using ``Effect/broadcast(_:channel:file:function:line:)`` to push into the socket the `supervise` owns.

They never reference each other directly; they meet on the shared channel id.

```swift
import SwiftRex

struct Message: Sendable, Equatable { … }
struct Socket: Sendable {
    let onMessage: @Sendable (@escaping @Sendable (Message) -> Void) -> Void
    let write: @Sendable (String) -> Void
    let close: @Sendable () -> Void
}

struct ChatEnv: Sendable { let connect: @Sendable (String) -> Socket }

enum ChatAction: Sendable {
    case join(String), leave
    case send(String)
    case received(Message)
}

struct ChatState: Sendable {
    var room: String?
    var log: [Message] = []
}

let chat = Behavior<ChatAction, ChatState, ChatEnv>
    .reduce { action, state in
        switch action {
        case .join(let id): state.room = id
        case .leave: state.room = nil
        case .received(let m): state.log.append(m)
        case .send: break                                       // the write is a side-effect, see react
        }
    }
    .produce { action, _ in
        guard case .send(let text) = action else { return Producer { _ in .empty } }
        return Producer { _ in .broadcast(text, channel: "chat-socket") }    // → into the live socket
    }
    .supervise { state in
        Supervision { env in
            guard let room = state.room else { return [] }      // not in a room → socket closed
            return [Channel(id: "chat-socket", lifetime: .ephemeral(resetKey: room)) { dispatch in
                let socket = env.connect(room)
                socket.onMessage { dispatch(.received($0)) }    // inbound → actions
                return ChannelHandler(receive: { socket.write($0) },   // outbound (piped in) → socket
                                      cancel:  { socket.close() })      // teardown, once
            }]
        }
    }
```

### The rendezvous

The `.produce` for `.send` and the `Channel` in `supervise` **share the id `"chat-socket"`**. That shared key is the entire wiring:

1. `supervise` opens the socket and registers it under `"chat-socket"`. Its ``ChannelHandler/receive`` is `socket.write`.
2. `.send("hi")` returns ``Effect/broadcast(_:channel:file:function:line:)`` targeting `"chat-socket"`. The engine finds the live channel by id and calls its `receive("hi")` — i.e. `socket.write("hi")`. **No new socket is opened.**

A `broadcast` is *not* deduped — sending `"hi"` twice writes twice, which is exactly what you want for discrete messages. (Contrast ``Broadcasting/onChange(_:)``, which is for *state-derived* values and dedups.)

### Why the knobs

- **`.ephemeral(resetKey: room)`** — switch rooms and the socket reconnects: the old room's socket closes, a fresh one opens for the new room. The `.send` path keeps working across the switch because the id is stable.
- **`.leave` ⇒ `[]` ⇒ close** — leaving sets `room = nil`, the supervision returns `[]`, and the engine closes the socket. A `broadcast` arriving after that finds nothing live and is harmlessly dropped.
- **`ChannelHandler(receive:cancel:)`** (not `cancelOnly`) — this socket is two-way, so it has a real `receive`. A pure-receiver feed would use ``ChannelHandler/cancelOnly(_:)`` instead — see <doc:ExampleWebSocket>.

## See Also

- <doc:StateDrivenEffects>
- <doc:Channels>
- <doc:ExampleWebSocket>
- ``Effect/broadcast(_:channel:file:function:line:)``
- ``ChannelHandler``
