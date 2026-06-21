import CoreFP

/// A long-lived, keyed resource a `Reaction` keeps alive while the state implies it — a socket, a
/// location stream, a poll, a fetch. It dispatches actions *out* (inbound events) and may accept
/// values piped *in* (a socket you broadcast to). Define one and the engine maintains it across
/// state changes; you never write the teardown — leaving the state that implied it is the cancellation.
///
/// Two orthogonal knobs drive how the engine reconciles it cycle-to-cycle:
///
/// - ``Lifetime`` — ``Lifetime/permanent`` opens once and keeps it open; `Lifetime.ephemeral(resetKey:)`
///   **recreates** it (close + reopen) whenever `resetKey` changes (a fetch keyed to a query, a socket
///   keyed to a room).
/// - ``Broadcasting`` — ``Broadcasting/nothing`` opens without delivering; ``Broadcasting/onChange(_:)``
///   auto-publishes the value on open **and** whenever it changes (a cursor you continuously broadcast).
///
/// ```swift
/// // a socket, alive while connected, that you also broadcast messages into from actions
/// Channel(id: "socket") { dispatch in
///     let s = openSocket()
///     s.onMessage { dispatch(.received($0)) }
///     return ChannelHandler(receive: { s.write($0) }, cancel: { s.close() })
/// }
///
/// // a cursor broadcast — auto-publishes the position whenever it moves
/// Channel(id: "cursor", broadcasting: .onChange(state.myCursor)) { dispatch in … }
///
/// // a fetch — recreated whenever the query changes, receive-only
/// Channel(id: "search", lifetime: .ephemeral(resetKey: query)) { dispatch in
///     let task = api.search(query) { dispatch(.loaded($0)) }
///     return .cancelOnly { task.cancel() }
/// }
/// ```
public struct Channel<Action: Sendable>: Sendable {
    /// The registry key (a **global**, type-aware namespace shared with action-driven effects).
    package let id: AnyHashableSendable
    /// Identity for the recreate diff: the `ephemeral` reset key, or `nil` for a `permanent` channel.
    package let resetIdentity: AnyHashableSendable?
    /// Identity for the broadcast diff: the `onChange` value, or `nil` when broadcasting `nothing`.
    package let broadcastIdentity: AnyHashableSendable?
    /// The single engine component (a keyed channel) this resource opens.
    package let component: Effect<Action>.Component

    /// Creates a channel.
    ///
    /// - Parameters:
    ///   - id: The channel key. The same id an action pipes into via `Effect.broadcast(_:channel:)`.
    ///   - lifetime: ``Lifetime/permanent`` (default) or `Lifetime.ephemeral(resetKey:)`.
    ///   - broadcasting: ``Broadcasting/nothing`` (default) or ``Broadcasting/onChange(_:)``.
    ///   - file/function/line: Captured automatically for the actions `dispatch` produces.
    ///   - body: Opens the resource on first use; `dispatch` sends inbound events out as actions.
    ///     Returns a ``ChannelHandler`` (receive + cancel), or ``ChannelHandler/cancelOnly(_:)``.
    public init<Value: Hashable & Sendable>(
        id: some Hashable & Sendable,
        lifetime: Lifetime = .permanent,
        broadcasting: Broadcasting<Value> = .nothing,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        _ body: @escaping @Sendable (_ dispatch: @escaping @Sendable (Action) -> Void) -> ChannelHandler<Value>
    ) {
        let key = AnyHashableSendable(id)
        self.id = key
        switch lifetime {
        case .permanent: self.resetIdentity = nil
        case .ephemeral(let resetKey): self.resetIdentity = resetKey
        }

        // `value` is delivered on open/pipe only when broadcasting; `.nothing` opens value-less.
        let value: any Sendable
        let deliversOnOpen: Bool
        switch broadcasting {
        case .nothing:
            self.broadcastIdentity = nil
            value = ChannelLifetimeMarker()
            deliversOnOpen = false
        case .onChange(let broadcastValue):
            self.broadcastIdentity = AnyHashableSendable(broadcastValue)
            value = broadcastValue
            deliversOnOpen = true
        }

        let source = ActionSource(file: file, function: function, line: line)
        let channel = Effect<Action>.Component.Channel(
            value: value,
            start: { firstValue, send, _ in
                let dispatch: @Sendable (Action) -> Void = { send(DispatchedAction($0, dispatcher: source)) }
                let handler = body(dispatch)
                if deliversOnOpen, let first = firstValue as? Value { handler.receive(first) }
                let sink: @Sendable (any Sendable) -> Void = { erased in
                    if let next = erased as? Value { handler.receive(next) }
                }
                return (SubscriptionToken(handler.cancel), sink)
            }
        )
        self.component = Effect<Action>.Component(
            subscribe: { _, complete in complete(); return .empty },
            channel: channel,
            scheduling: .keyed(id: key)
        )
    }
}

// MARK: - Knobs

extension Channel {
    /// How long the engine keeps a channel alive, and what triggers a recreate.
    public enum Lifetime: Sendable {
        /// Open once and keep it open across state changes; cancelled only when it leaves the desired set.
        case permanent
        /// Recreate the channel (close + reopen) whenever `resetKey` changes between reconcile cycles.
        case ephemeral(resetKey: AnyHashableSendable)

        /// Recreate whenever `resetKey` changes (accepts any `Hashable & Sendable` key).
        @_disfavoredOverload
        public static func ephemeral(resetKey: some Hashable & Sendable) -> Lifetime {
            .ephemeral(resetKey: AnyHashableSendable(resetKey))
        }
    }
}

/// What a channel auto-publishes from state — deduped and idempotent (so it survives time-travel).
/// For discrete, possibly-repeated sends use the action-driven `Effect.broadcast(_:channel:)` instead.
public enum Broadcasting<Value: Hashable & Sendable>: Sendable {
    /// Open without delivering anything; the channel is fed (if at all) by action-driven broadcasts.
    case nothing
    /// Publish `value` on open and whenever it changes; identical consecutive values are not re-sent.
    case onChange(Value)
}

/// Placeholder `value` for a `Broadcasting/nothing` channel — passed as the ignored `firstValue` to a
/// value-less open, never delivered.
struct ChannelLifetimeMarker: Sendable {}
