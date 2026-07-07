# State-Driven Effects

Some side-effects shouldn't be started by an action — they should exist *for as long as the state says so*. That's the `supervise` axis.

## Overview

There are two kinds of side-effects, and SwiftRex gives each its own axis.

**Action-driven (`produce`)** — *"this happened, so do that."* A `.tapSearch` fires a request; a `.save` writes to disk. The action is the cause; the effect is a one-shot reaction that runs, dispatches a result action, and finishes. This is the **Effect Producer** (Elm calls it a **`Cmd`**). You write it with `produce` (on a ``Behavior`` or ``Middleware``); the ``Store`` *performs* the ``Effect`` it describes, resolved by a `Reader` from the post-mutation context.

**State-driven (`supervise`)** — *"while the state looks like this, keep this resource alive."* A timer that ticks while a screen is visible; a socket that stays open while a room is joined; a poll that runs while a query is set. No single action starts or stops it — *the state implies it*, and leaving that state **is** the teardown. This is the **Effect Supervisor** (Elm calls it a **`Sub`**). You write it with `supervise`, returning a ``Supervision`` — a `Reader` from the environment to the ``Channel``s to ``Keep`` alive.

```swift
let room = Behavior<RoomAction, RoomState, RoomEnv>
    .reduce { action, state in
        switch action {
        case .join(let id): state.joinedRoom = id
        case .leave: state.joinedRoom = nil
        case .received(let msg): state.messages.append(msg)
        }
    }
    .supervise { state in
        Supervision { env in
            guard let id = state.joinedRoom else { return [] }   // no room → no socket
            return [Channel(id: id) { dispatch in
                let socket = env.connect(id)
                socket.onMessage { dispatch(.received($0)) }
                return ChannelHandler(receive: { socket.write($0) }, cancel: { socket.close() })
            }]
        }
    }
```

When `joinedRoom` is `nil` the supervision returns `[]`, the engine sees the socket is no longer desired, and closes it. You never wrote `socket.close()` against a `.leave` action — *leaving the state that implied the socket cancels it.*

### The three axes of a feature

A ``Behavior`` folds three independent concerns, each a fluent builder that composes by `<>`:

| Role | Builder | Cause | Returns | Elm |
|---|---|---|---|---|
| **Reducer** | `reduce` | an action | an `inout` mutation (Store *maintains* state) | *(update)* |
| **Effect Producer** | `produce` | an action | an ``Effect`` (Store *performs*) | `Cmd` |
| **Effect Supervisor** | `supervise` | the *state* | a ``Supervision`` → a ``Keep`` of ``Channel``s (Store *supervises*) | `Sub` |

```swift
Behavior
    .reduce { action, state in … }   // what changes
    .produce { action, ctx in … }    // what to do because of an action
    .supervise { state in … }        // what to keep alive while the state holds
```

A ``Middleware`` carries the same two effect axes (`produce` and `supervise`) — it just never mutates. ``Reducer`` owns only the first.

### How it runs — reconcile, not re-fire

`produce` and `supervise` are scheduled differently, and that difference is the whole point.

- A `produce` effect is **recreated** each time its action fires: dispatch `.search` twice and the second run cancels and replaces the first (when keyed).
- A `supervise` channel is **reconciled**. After every state mutation the ``Store`` recomputes the whole desired set (`supervisor(state)`) and diffs it against what's running: channels newly present **open**, channels now absent **cancel**, and channels still present are **left untouched** — an unchanged desired set produces *zero* operations. The engine keeps the registry; your code keeps nothing. This is what makes it survive time-travel and redelivery: the desired set is a pure function of state.

Two identities drive the diff independently — see ``Channel/Lifetime`` (recreate on reset) and ``Broadcasting`` (re-publish on change) in <doc:Channels>.

### It threads through lifting

`supervise` is not a leaf-only feature. Every lift carries it: `liftState` focuses the channels onto a sub-state (state-driven nav — when the sub-state is gone, its channels cancel), `liftAction` re-embeds their dispatched actions, `liftEnvironment` adapts their dependencies, and `liftCollection` / `liftEach` fan a per-element behavior's channels across a collection, stamping each element's ids so element A's `"socket"` never collides with element B's. See <doc:Lifting>.

### When to reach for each

- **`produce`** — a request triggered by a tap, a save, an analytics ping, a navigation side-effect. Anything caused by *an action* and *finished* once its result comes back.
- **`supervise`** — a websocket, a location/audio pipeline, a timer, a poll, a Combine subscription, a server-sent-events stream. Anything whose lifetime is implied by *state* and must outlive the action that set that state.

A two-way resource uses both: `supervise` keeps the socket open (the *listen* side), and a `produce` returning ``Effect/broadcast(_:channel:file:function:line:)`` sends into it by id (the *send* side). They rendezvous on the channel id — see <doc:ExampleChatRoom>.

## Topics

### Worked Examples

- <doc:Channels>
- <doc:ExampleTimer>
- <doc:ExamplePolling>
- <doc:ExampleChatRoom>
- <doc:ExampleWebSocket>
- <doc:ExampleDelay>

### The Types

- ``Channel``
- ``Supervision``
- ``Keep``
- ``Consequence``
- ``ChannelHandler``

## See Also

- <doc:AddingEffects>
- ``Behavior``
- ``Middleware``
- ``Effect``
