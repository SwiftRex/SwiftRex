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
    /// Debounce window for **creation**: when set (an `ephemeral` `settle`), a change to `resetIdentity`
    /// tears the live instance down immediately and defers the *recreation* until the key is quiet this
    /// long. `nil` recreates immediately. Never affects value delivery — only the open.
    package let settle: Duration?
    /// The single engine component (a keyed channel) this resource opens.
    package let component: Effect<Action>.Component

    /// Creates a channel.
    ///
    /// - Parameters:
    ///   - id: The channel key. The same id an action pipes into via `Effect.broadcast(_:channel:)`.
    ///   - lifetime: ``Lifetime/permanent`` (default) or `Lifetime.ephemeral(resetKey:settle:)`.
    ///   - broadcasting: ``Broadcasting/nothing`` (default) or ``Broadcasting/onChange(_:)``.
    ///   - delivery: How to pace values flowing *into* the channel — ``ChannelDelivery/immediate``
    ///     (default), or throttle/debounce. Gates delivery only; the channel still opens immediately.
    ///   - file/function/line: Captured automatically for the actions `dispatch` produces.
    ///   - body: Opens the resource on first use; `dispatch` sends inbound events out as actions.
    ///     Returns a ``ChannelHandler`` (receive + cancel), or ``ChannelHandler/cancelOnly(_:)``.
    public init<Value: Hashable & Sendable>(
        id: some Hashable & Sendable,
        lifetime: Lifetime = .permanent,
        broadcasting: Broadcasting<Value> = .nothing,
        delivery: ChannelDelivery = .immediate,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        _ body: @escaping @Sendable (_ dispatch: @escaping @Sendable (Action) -> Void) -> ChannelHandler<Value>
    ) {
        let key = AnyHashableSendable(id)
        self.id = key
        switch lifetime {
        case .permanent:
            self.resetIdentity = nil
            self.settle = nil
        case let .ephemeral(resetKey, settle):
            self.resetIdentity = resetKey
            self.settle = settle
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
            },
            delivery: delivery,
            deliversOnOpen: deliversOnOpen
        )
        self.component = Effect<Action>.Component(
            subscribe: { _, complete in complete(); return .empty },
            channel: channel,
            scheduling: .keyed(id: key)
        )
    }
}

// MARK: - Lift support

extension Channel {
    /// Memberwise init from the already-computed fields (used by ``mapAction(_:)`` and the lifts).
    package init(
        id: AnyHashableSendable,
        resetIdentity: AnyHashableSendable?,
        broadcastIdentity: AnyHashableSendable?,
        settle: Duration?,
        component: Effect<Action>.Component
    ) {
        self.id = id
        self.resetIdentity = resetIdentity
        self.broadcastIdentity = broadcastIdentity
        self.settle = settle
        self.component = component
    }

    /// Re-types the dispatched actions via `f`, keeping the id, diff identities, settle, and delivery.
    /// Used by the action-axis lifts to re-embed a feature's channel actions into the global type.
    package func mapAction<B: Sendable>(_ f: @escaping @Sendable (Action) -> B) -> Channel<B> {
        Channel<B>(
            id: id,
            resetIdentity: resetIdentity,
            broadcastIdentity: broadcastIdentity,
            settle: settle,
            component: Effect(components: [component]).map(f).components[0]
        )
    }

    /// Scopes this channel's key under `element` — `ElementScopedID(element:, inner: id)` — so the
    /// same channel id in two different collection elements stays independent (element A's `"socket"`
    /// ≠ element B's `"socket"`). Used by the collection lifts' per-element id stamping.
    package func scopedToElement(_ element: AnyHashableSendable) -> Channel {
        Channel(
            id: AnyHashableSendable(ElementScopedID(element: element, inner: id)),
            resetIdentity: resetIdentity,
            broadcastIdentity: broadcastIdentity,
            settle: settle,
            component: Effect(components: [component]).scopedToElement(element).components[0]
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
        ///
        /// `settle` debounces the *recreation*: a key change tears the live instance down immediately and
        /// waits for the key to be quiet for `settle` before opening the new one — search-as-you-type
        /// reconnection without thrashing. `nil` recreates immediately. It paces creation only; values
        /// flowing through a live instance are paced by ``ChannelDelivery`` instead.
        case ephemeral(resetKey: AnyHashableSendable, settle: Duration?)

        /// Recreate whenever `resetKey` changes (accepts any `Hashable & Sendable` key); `settle`
        /// optionally debounces the recreation.
        @_disfavoredOverload
        public static func ephemeral(resetKey: some Hashable & Sendable, settle: Duration? = nil) -> Lifetime {
            .ephemeral(resetKey: AnyHashableSendable(resetKey), settle: settle)
        }
    }
}

/// How the engine paces values delivered *into* a live ``Channel`` (from ``Broadcasting/onChange(_:)``
/// or ``Effect/broadcast(_:channel:file:function:line:)``) — the channel acting as a throttled subject.
///
/// This gates *delivery only*; the channel always opens immediately the moment it enters the desired set.
/// Creation pacing is a separate concern — see `Channel.Lifetime.ephemeral`'s `settle`. Applying it twice
/// (here and on an upstream publisher) double-paces, exactly like two `.throttle`s in one pipeline.
public enum ChannelDelivery: Sendable, Equatable {
    /// Deliver every value as it arrives.
    case immediate
    /// Deliver at most once per `interval`; values arriving inside the window are dropped.
    case throttle(Duration)
    /// Deliver only after the values go quiet for `interval`; each new value restarts the wait, so only
    /// the latest survives a burst.
    case debounce(Duration)
}

extension ChannelDelivery {
    /// Maps an ``EffectScheduling``'s coalesce policy onto channel delivery pacing — the bridge for the
    /// action-driven ``Effect/channel(value:scheduling:file:function:line:_:)`` factory, whose
    /// `scheduling` now paces *delivery* (the channel always opens immediately).
    package init(coalesce: EffectScheduling.Coalesce?) {
        switch coalesce {
        case .throttle(let interval): self = .throttle(interval)
        case .debounce(let window): self = .debounce(window)
        case nil: self = .immediate
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
