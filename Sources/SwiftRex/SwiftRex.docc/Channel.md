# ``SwiftRex/Channel``

A long-lived, keyed resource a ``Supervision`` keeps alive while the state implies it — a socket, a location stream, a poll, a timer.

## Overview

Where an ``Effect`` is a one-shot you *fire*, a `Channel<Action>` is a resource you *declare*. You describe how to open it (and how to close it); the ``Store``'s engine decides *when*, by diffing the set a ``Supervision`` returns each reconcile cycle against what is already running. You never write the teardown — leaving the state that implied the channel **is** the cancellation.

A channel dispatches actions *out* (inbound events become actions) and may accept values piped *in* (a socket you ``Effect/broadcast(_:channel:file:function:line:)`` into). The `id` is the registry key; it lives in the same global, type-aware namespace as action-driven effects, so a `produce` and a `supervise` rendezvous on a shared id.

```swift
// a socket, alive while connected, that you also broadcast messages into from actions
Channel(id: "socket") { dispatch in
    let s = openSocket()
    s.onMessage { dispatch(.received($0)) }
    return ChannelHandler(receive: { s.write($0) }, cancel: { s.close() })
}

// a fetch — recreated whenever the query changes, receive-only
Channel(id: "search", lifetime: .ephemeral(resetKey: query)) { dispatch in
    let task = api.search(query) { dispatch(.loaded($0)) }
    return .cancelOnly { task.cancel() }
}
```

## Three orthogonal knobs

The engine reconciles each channel cycle-to-cycle by three independent diffs:

- ``Channel/Lifetime`` — ``Channel/Lifetime/permanent`` opens once and keeps it open; `.ephemeral(resetKey:settle:)` **recreates** it (close + reopen) whenever `resetKey` changes. `settle` debounces the *recreation* (search-as-you-type without thrashing) — it paces the **open**, never value delivery.
- ``Broadcasting`` — ``Broadcasting/nothing`` opens value-less; ``Broadcasting/onChange(_:)`` auto-publishes the value on open and whenever it changes (deduped, so it survives time-travel).
- ``ChannelDelivery`` — paces values flowing *into* a live channel: ``ChannelDelivery/immediate``, `.throttle`, or `.debounce`. Gates *delivery* only; the channel still opens immediately.

`Lifetime`'s `settle` (creation pacing) and `ChannelDelivery` (delivery pacing) are separate concerns — see <doc:Channels> for the full model and <doc:ExampleWebSocket> for the two knobs working together.

## Topics

### Creating a Channel

- ``Channel/init(id:lifetime:broadcasting:delivery:file:function:line:_:)``
- ``ChannelHandler``

### The knobs

- ``Channel/Lifetime``
- ``Broadcasting``
- ``ChannelDelivery``

## See Also

- ``Supervision``
- ``Keep``
- ``Effect``
- <doc:Channels>
- <doc:StateDrivenEffects>
