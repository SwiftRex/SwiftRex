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
///     .react { env in
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

extension ChannelHandler where Value == Never {
    /// A handler for a **pure receiver** — a channel that is never piped into, only feeds events out
    /// via `send` and tears down on `cancel` (a location stream, server-sent events). The `Value`
    /// is `Never`, so there is nothing to `receive`.
    ///
    /// ```swift
    /// .channel(id: "location") { send in
    ///     let mgr = startLocationUpdates(); mgr.onUpdate { send(.located($0)) }
    ///     return .cancelOnly { mgr.stop() }
    /// }
    /// ```
    ///
    /// - Parameter cancel: Tears the resource down when the channel leaves the desired set.
    public static func cancelOnly(_ cancel: @escaping @Sendable () -> Void) -> ChannelHandler<Never> {
        ChannelHandler(receive: { _ in }, cancel: cancel)
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
                    },
                    delivery: ChannelDelivery(coalesce: scheduling.coalesce)
                ),
                scheduling: scheduling
            )
        ])
    }
}

// MARK: - Broadcast (action-driven send into a channel owned elsewhere)

extension Effect {
    /// Sends `value` into the **live channel** registered under `channel`, without opening anything.
    ///
    /// This is the action-driven *send* half of a long-lived channel: a `Reaction` keeps the channel
    /// alive (Elm's `listen`), and a `Middleware` routes a value into it by key (Elm's `send`). They
    /// rendezvous on the shared id in the Store's effect registry. Unlike a reaction's
    /// `broadcasting: .onChange`, a `.broadcast` is **not** deduped — it delivers on every call, so
    /// sending the same value twice sends it twice.
    ///
    /// ```swift
    /// // A reaction owns the socket's lifetime, keyed "socket":
    /// Channel(id: "socket") { dispatch in
    ///     let s = openSocket(); s.onMessage { dispatch(.received($0)) }
    ///     return ChannelHandler(receive: { s.write($0) }, cancel: { s.close() })
    /// }
    ///
    /// // An action sends a message into that same socket — no body, no reopening:
    /// case .send(let text):
    ///     .react { _ in .broadcast(text, channel: "socket") }
    /// ```
    ///
    /// A broadcast **never opens** a channel: if nothing is live under `channel` the value is dropped.
    /// Keep the channel alive (via a reaction or an earlier `.open`) for it to land. The `value`'s type
    /// must match the live channel's — a mismatch is silently dropped.
    ///
    /// - Parameters:
    ///   - value: The value to deliver into the live channel.
    ///   - channel: The channel key (the same id the channel was opened under).
    ///   - file/function/line: Captured automatically (carried for symmetry; a broadcast emits no actions).
    /// - Returns: A single-component ``Effect`` that delivers `value` into the channel keyed `channel`.
    public static func broadcast<Value: Sendable>(
        _ value: Value,
        channel id: some Hashable & Sendable,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        Effect(components: [
            Component(
                subscribe: { _, complete in complete(); return .empty },
                channel: Component.Channel(value: value, start: nil), // send-only: never opens
                scheduling: .keyed(id: id)
            )
        ])
    }
}

// MARK: - Open / cancel a Channel imperatively (action-driven lifetime)

extension Effect {
    /// Opens a ``Channel`` imperatively — the action-driven way to start a long-lived resource, with
    /// its lifetime managed by *you* (via ``cancel(id:)``) instead of by a reaction's reconcile.
    ///
    /// The same `Channel` value can be opened here (a middleware reacting to `.connect`) or maintained
    /// declaratively by a `Reaction`; both rendezvous on the channel's id, so a socket opened in either
    /// world receives `.broadcast`s from the other.
    ///
    /// ```swift
    /// case .connect:    .react { _ in .open(socketChannel) }
    /// case .send(let t): .react { _ in .broadcast(t, channel: "socket") }
    /// case .disconnect:  .react { _ in .cancel(id: "socket") }
    /// ```
    ///
    /// - Parameter channel: The channel to open. Its `lifetime`/`broadcasting` are honoured.
    /// - Returns: A single-component ``Effect`` that opens `channel`.
    public static func open(_ channel: Channel<Action>) -> Self {
        Effect(components: [channel.component])
    }
}

// MARK: - Channel sugar: AsyncStream

extension Effect {
    /// Creates a pipeable ``channel(value:scheduling:file:function:line:_:)`` whose body consumes the
    /// piped values as an `AsyncStream` — the rich layer over the raw ``ChannelHandler`` sink, for
    /// when you want `for await` and async-sequence operators instead of a per-value callback.
    ///
    /// Each piped value is yielded into `values`; the channel ends when `consume` returns or `cancel`
    /// fires (which finishes the stream and cancels the consuming task). This is the natural seam to
    /// bridge a reactive publisher: feed it into the stream from inside `consume`.
    ///
    /// ```swift
    /// // Debounce a live search over a single long-lived stream — the consumer stays alive.
    /// case .queryChanged(let text):
    ///     .react { env in
    ///         .channel(value: text, scheduling: .debounce(id: "search", delay: .milliseconds(300))) { queries, send, _ in
    ///             for await query in queries {
    ///                 let results = await env.api.search(query)
    ///                 send(.results(results))
    ///             }
    ///         }
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - value: The value to pipe this dispatch.
    ///   - scheduling: The ``EffectScheduling`` policy; its `id` must be set (see the sink form).
    ///   - bufferingPolicy: The backing `AsyncStream` buffering policy. Defaults to `.unbounded`.
    ///   - file: Source file — captured automatically.
    ///   - function: Function name — captured automatically.
    ///   - line: Source line — captured automatically.
    ///   - consume: Drives the channel: reads piped values from `values`, dispatches actions via
    ///     `send`, and may end the channel via `complete`. Runs until it returns or the channel is cancelled.
    /// - Returns: A single-component ``Effect`` carrying the pipeable channel.
    public static func channel<Value: Sendable>(
        value: Value,
        scheduling: EffectScheduling,
        bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy = .unbounded,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        consume: @escaping @Sendable (
            _ values: AsyncStream<Value>,
            _ send: @escaping @Sendable (Action) -> Void,
            _ complete: @escaping @Sendable () -> Void
        ) async -> Void
    ) -> Self {
        channel(value: value, scheduling: scheduling, file: file, function: function, line: line) { send, complete in
            let (stream, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy: bufferingPolicy)
            let task = Task { await consume(stream, send, complete) }
            return ChannelHandler(
                receive: { continuation.yield($0) },
                cancel: { continuation.finish(); task.cancel() }
            )
        }
    }
}
