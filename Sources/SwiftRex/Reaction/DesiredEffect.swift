import CoreFP

/// One state-driven effect a ``Reaction`` declares should be alive for the current state.
///
/// A `Reaction` returns the **complete** set of these for a given state every cycle; the engine
/// diffs successive sets by `id` and starts, stops, or re-schedules each. You never write the
/// start/stop/pipe — leaving the condition that produced a `DesiredEffect` *is* its cancellation.
public struct DesiredEffect<Action: Sendable>: Sendable {
    /// The reaction key the engine reconciles by — a **global** namespace shared with action-driven
    /// effects (Elm keys WebSocket connections by URL the same way). Identity is type-aware, so a
    /// module-private `enum` id isolates a feature automatically while a shared id type lets features
    /// deliberately address the same channel (e.g. one core-owned socket, many features piping in).
    package let id: AnyHashableSendable
    /// The effect to run while desired — a pipeable channel or a one-shot.
    package let effect: Effect<Action>
    /// Change-detector: when it differs from last cycle the engine re-schedules (pipes a channel,
    /// recreates a one-shot). `nil` means presence-only — started once and kept alive while present.
    package let version: AnyHashableSendable?

    package init(id: AnyHashableSendable, effect: Effect<Action>, version: AnyHashableSendable?) {
        self.id = id
        self.effect = effect
        self.version = version
    }
}

// MARK: - Builders

extension DesiredEffect {
    /// A long-lived channel kept alive **while desired**, with no value — it opens once when it enters
    /// the desired set, feeds inbound events back as actions through `send`, and is cancelled when it
    /// drops out. This is the lifetime half of a socket (Elm's `listen`/`keepAlive`).
    ///
    /// Opening delivers **nothing** (unlike ``channel(id:value:coalesce:file:function:line:_:)``). To
    /// *send* into it, an action routes a value by the same `id` with
    /// ``Effect/pipe(_:into:file:function:line:)`` — the channel's ``ChannelHandler/receive`` is where
    /// those piped values land. For a pure receiver that is never piped into, use
    /// ``ChannelHandler/cancelOnly(_:)``.
    ///
    /// ```swift
    /// // A socket open while connected: inbound → actions, outbound via `.pipe(_, into: "socket")`.
    /// Reaction<AppState, AppAction> { state in
    ///     guard state.isConnected else { return [] }   // leaving "connected" closes it for you
    ///     return [
    ///         .channel(id: "socket") { send in
    ///             let socket = openSocket()
    ///             socket.onMessage { send(.received($0)) }
    ///             return ChannelHandler(receive: { socket.write($0) }, cancel: { socket.close() })
    ///         }
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - id: The channel key. The same `id` an action pipes into via `Effect.pipe(_:into:)`.
    ///   - file/function/line: Captured automatically for the actions `send` produces.
    ///   - body: Opens the resource on first use; `send` dispatches inbound events as actions. Returns a
    ///     ``ChannelHandler`` whose `receive` handles future pipes and whose `cancel` tears it down.
    public static func channel<Value: Sendable>(
        id: some Hashable & Sendable,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        _ body: @escaping @Sendable (_ send: @escaping @Sendable (Action) -> Void) -> ChannelHandler<Value>
    ) -> Self {
        let key = AnyHashableSendable(id)
        let source = ActionSource(file: file, function: function, line: line)
        // `value` is a placeholder never delivered (value-less open); `start` ignores firstValue &
        // complete so it opens without an initial send and cannot self-complete.
        let channel = Effect<Action>.Component.Channel(
            value: ChannelLifetimeMarker(),
            start: { _, send, _ in
                let rawSend: @Sendable (Action) -> Void = { send(DispatchedAction($0, dispatcher: source)) }
                let handler = body(rawSend)
                let sink: @Sendable (any Sendable) -> Void = { erased in
                    if let next = erased as? Value { handler.receive(next) }
                }
                return (SubscriptionToken(handler.cancel), sink)
            }
        )
        let component = Effect<Action>.Component(
            subscribe: { _, complete in complete(); return .empty },
            channel: channel,
            scheduling: .keyed(id: key)
        )
        return .init(id: key, effect: Effect(components: [component]), version: nil)   // presence-only
    }

    /// A pipeable channel that **broadcasts a piece of state**, with change-detection inferred from
    /// `value`: whenever the (Hashable) value changes between cycles the engine pipes it into the same
    /// live channel; when the channel drops out of the desired set it is cancelled.
    ///
    /// Use this when the thing being sent *is* state — a cursor position, a "user is typing" flag, a
    /// collaborative document's text — where "send it when it changes, stay silent otherwise" is the
    /// correct behaviour and there is no memory burden (the value lives in state). For discrete
    /// **events** (chat messages, commands) use ``channel(id:file:function:line:_:)`` for the lifetime
    /// and ``Effect/pipe(_:into:file:function:line:)`` from an action for each send instead — value
    /// identity would otherwise dedupe a repeated send and force you to carry the last value in state.
    ///
    /// ```swift
    /// // Broadcast my cursor whenever it moves; an unchanged position sends nothing.
    /// Reaction<BoardState, BoardAction> { state in
    ///     guard let session = state.session else { return [] }
    ///     return [.channel(id: "cursor", value: state.myCursor) { send, _ in
    ///         let socket = openCursorChannel(session)
    ///         socket.onMessage { send(.peerMoved($0)) }
    ///         return ChannelHandler(receive: { socket.write(encode($0)) }, cancel: { socket.close() })
    ///     }]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - id: The reaction key (owner-stamped at lift). Identifies the live channel across cycles.
    ///   - value: The value to pipe; its `Hashable` identity drives change-detection.
    ///   - coalesce: Optional `debounce`/`throttle` gating the value delivery (not the lifetime).
    ///   - file/function/line: Captured automatically for the produced actions' source.
    ///   - body: Opens the resource on first use and returns a ``ChannelHandler``.
    public static func channel<Value: Hashable & Sendable>(
        id: some Hashable & Sendable,
        value: Value,
        coalesce: EffectScheduling.Coalesce? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        _ body: @escaping @Sendable (
            _ send: @escaping @Sendable (Action) -> Void,
            _ complete: @escaping @Sendable () -> Void
        ) -> ChannelHandler<Value>
    ) -> Self {
        let key = AnyHashableSendable(id)
        let scheduling = EffectScheduling(id: key, coalesce: coalesce)
        let effect = Effect<Action>.channel(value: value, scheduling: scheduling, file: file, function: function, line: line, body)
        return .init(id: key, effect: effect, version: AnyHashableSendable(value))
    }

    /// A one-shot effect kept alive **while present** — started once when it enters the desired set,
    /// cancelled when it drops out. Presence-only: no change-detection (use ``effect(id:version:_:)``
    /// to re-run on a changing input).
    ///
    /// ```swift
    /// // Poll while the dashboard is visible; leaving the screen cancels it.
    /// state.screen == .dashboard ? [.effect(id: "poll", pollEffect)] : []
    /// ```
    public static func effect(id: some Hashable & Sendable, _ effect: Effect<Action>) -> Self {
        .init(id: AnyHashableSendable(id), effect: effect, version: nil)
    }

    /// A one-shot effect re-run whenever `version` changes (and cancelled when it drops out of the
    /// desired set) — e.g. a fetch keyed to the current query.
    public static func effect<Version: Hashable & Sendable>(
        id: some Hashable & Sendable,
        version: Version,
        _ effect: Effect<Action>
    ) -> Self {
        .init(id: AnyHashableSendable(id), effect: effect, version: AnyHashableSendable(version))
    }
}

/// Placeholder `value` for a value-less reaction ``DesiredEffect/channel(id:file:function:line:_:)``:
/// the channel opens without delivering, so this is passed as the ignored `firstValue` and never piped.
private struct ChannelLifetimeMarker: Sendable {}
