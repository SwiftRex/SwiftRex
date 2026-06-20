import CoreFP

/// One state-driven effect a ``Reaction`` declares should be alive for the current state.
///
/// A `Reaction` returns the **complete** set of these for a given state every cycle; the engine
/// diffs successive sets by `id` and starts, stops, or re-schedules each. You never write the
/// start/stop/pipe — leaving the condition that produced a `DesiredEffect` *is* its cancellation.
public struct DesiredEffect<Action: Sendable>: Sendable {
    /// The reaction key the engine reconciles by. Owner-stamped automatically at lift boundaries so
    /// two independently-authored features can both use `"socket"` without colliding.
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
    /// A pipeable channel kept alive while desired, with change-detection **inferred from `value`**:
    /// whenever the (Hashable) value changes between cycles the engine pipes it into the same live
    /// channel; when the channel drops out of the desired set it is cancelled.
    ///
    /// ```swift
    /// // A socket that stays open while connected, sending the latest outbox without reconnecting.
    /// Reaction<AppState, AppAction> { state in
    ///     guard state.isConnected else { return [] }
    ///     return [.channel(id: "socket", value: state.outbox) { send, _ in
    ///         let socket = openSocket()
    ///         socket.onMessage { send(.received($0)) }
    ///         return ChannelHandler(receive: { socket.write($0) }, cancel: { socket.close() })
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
