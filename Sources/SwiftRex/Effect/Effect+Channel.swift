// MARK: - Channel handler (author-facing, fully typed)

/// The body of an ``Effect/channel(value:scheduling:file:function:line:_:)`` returns this handler: a per-value
/// `receive` sink the Store calls for every piped value, plus a `cancel` torn down when the
/// channel is displaced or the Store deallocates.
///
/// A channel is a *long-lived* effect — a WebSocket, a location stream, an audio engine — that
/// you open **once** and then feed values into, instead of cancelling and recreating it on every
/// dispatch. The body opens the resource, wires its *outgoing* events to `send`, and returns the
/// handler describing how to *receive* the next value and how to shut down:
///
/// ```swift
/// // Throttle outgoing socket writes to 16 ms without ever closing the socket.
/// case .send(let byte):
///     .produce { env in
///         .channel(value: byte, scheduling: .throttle(id: "socket", interval: .milliseconds(16))) { send, complete in
///             let socket = env.openSocket()
///             socket.onMessage { send(.received($0)) }
///             socket.onClose { complete() }
///             return ChannelHandler(
///                 receive: { byte in socket.write(byte) },
///                 cancel: { socket.close() }
///             )
///         }
///     }
/// ```
///
/// The first `.send` opens the socket and writes the first byte; every later `.send` writes into
/// the **same** open socket (throttled), rather than reconnecting.
public struct ChannelHandler<Value: Sendable>: Sendable {
    /// Called by the Store for each value piped into the live channel (including the first).
    public let receive: @Sendable (Value) -> Void
    /// Called once when the channel is displaced, cancelled, or the Store deallocates.
    public let cancel: @Sendable () -> Void

    /// Creates a channel handler.
    ///
    /// - Parameters:
    ///   - receive: Delivers each piped value to the live effect (e.g. `socket.write`).
    ///   - cancel: Tears the effect down (e.g. `socket.close`).
    public init(
        receive: @escaping @Sendable (Value) -> Void,
        cancel: @escaping @Sendable () -> Void
    ) {
        self.receive = receive
        self.cancel = cancel
    }
}

// MARK: - Channel factory (pipeable, long-lived effect)

extension Effect {
    /// Creates a *pipeable* effect: a long-lived unit of work the Store starts once and then feeds
    /// subsequent values into, rather than cancelling and recreating on every dispatch.
    ///
    /// This is the non-destructive counterpart to the recreate-on-dispatch effects (``just(_:scheduling:file:function:line:)``
    /// & friends). Both remain first-class — reach for `channel` when tearing the effect down would
    /// be wrong: a WebSocket you must not reconnect, a `debounce`/`throttle` over a stream that has
    /// to stay open, an audio/location pipeline.
    ///
    /// The effect is keyed by `scheduling.id`, which is **required** — without an id there is no
    /// live instance to pipe into, so each dispatch would start a brand-new channel. On the first
    /// dispatch the Store runs `body` (opening the resource) and delivers `value`; on every later
    /// dispatch with the same id it delivers `value` into the already-running effect, honouring the
    /// `coalesce` policy (`debounce`/`throttle`) on the **value delivery** without tearing the
    /// effect down.
    ///
    /// - Parameters:
    ///   - value: The value to pipe this dispatch (e.g. the byte to write, the query to search).
    ///   - scheduling: The ``EffectScheduling`` policy. Its `id` identifies the live channel and
    ///     must be set; `debounce`/`throttle` gate value delivery, not the effect's lifetime.
    ///   - scheduling: see above.
    ///   - file: Source file — captured automatically.
    ///   - function: Function name — captured automatically.
    ///   - line: Source line — captured automatically.
    ///   - body: Opens the resource on first use and returns a ``ChannelHandler`` describing how to
    ///     receive each value and how to cancel. `send` dispatches actions out (with the channel's
    ///     captured call-site source); `complete` ends the channel.
    /// - Returns: A single-component ``Effect`` carrying the pipeable channel.
    public static func channel<Value: Sendable>(
        value: Value,
        scheduling: EffectScheduling,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        _ body: @escaping @Sendable (
            _ send: @escaping @Sendable (Action) -> Void,
            _ complete: @escaping @Sendable () -> Void
        ) -> ChannelHandler<Value>
    ) -> Self {
        let source = ActionSource(file: file, function: function, line: line)
        return Effect(components: [
            Component(
                subscribe: { _, complete in complete(); return .empty },
                channel: Component.Channel(
                    value: value,
                    start: { firstValue, send, complete in
                        let rawSend: @Sendable (Action) -> Void = { send(DispatchedAction($0, dispatcher: source)) }
                        let handler = body(rawSend, complete)
                        if let first = firstValue as? Value { handler.receive(first) }
                        let sink: @Sendable (any Sendable) -> Void = { erased in
                            if let next = erased as? Value { handler.receive(next) }
                        }
                        return (SubscriptionToken(handler.cancel), sink)
                    }
                ),
                scheduling: scheduling
            )
        ])
    }
}
