/// Declares how the ``Store`` should schedule and manage the lifecycle of an ``Effect`` component.
///
/// Every `Effect` component carries an `EffectScheduling` value. The Store reads it and decides
/// whether to start the work immediately, delay it, coalesce it (debounce/throttle), or replace an
/// existing component under the same `id`. Neither ``Middleware`` nor ``Behavior`` execute these
/// directives — they are purely instructions to the Store's scheduling engine.
///
/// ## Orthogonal knobs, not welded cases
///
/// `EffectScheduling` is a value of independent knobs:
///
/// - ``id`` — the registry key. `nil` means *anonymous* (a fresh key per run, used only to clean up
///   the entry when the component completes; an anonymous component cannot be cancelled).
/// - ``delay`` — a fixed wait before starting.
/// - ``coalesce`` — a ``Coalesce`` strategy on the input: ``Coalesce/debounce(_:)`` (wait for a quiet
///   period, restarting the timer on each new arrival) or ``Coalesce/throttle(_:)`` (run at most once
///   per interval, dropping arrivals inside the window).
/// - ``exclusive`` — at most one run under `id`: cancel any existing one before starting.
///
/// The factories below build the common combinations and read naturally at the call site —
/// `.debounce(id: "search", delay: .milliseconds(300))`, `.replacing(id: "fetch")` — while the knobs
/// remain individually settable for combinations the factories don't name.
///
/// ## Cancellation registry
///
/// Every component with an `id` shares the Store's effect registry. A component registered under
/// `"search"` can be cancelled with ``Effect/cancelInFlight(id:)`` regardless of how it was
/// scheduled. Id equality is **type-aware** (`1` Int, `1.0` Double, `true` Bool are distinct ids on
/// every platform) — prefer module-private enum ids so features never collide. See
/// ``AnyHashableSendable``.
///
/// ```swift
/// // Debounce live search: reset the 300 ms timer on every keystroke.
/// env.api.search(query).asEffect()
///     .scheduling(.debounce(id: "liveSearch", delay: .milliseconds(300)))
///
/// // At most one profile fetch at a time — a new one cancels the previous.
/// env.api.fetchProfile().asEffect()
///     .scheduling(.replacing(id: "profileFetch"))
/// ```
public struct EffectScheduling: Sendable, Equatable {
    /// The registry key. `nil` schedules anonymously (uncancellable, fresh key per run).
    public var id: AnyHashableSendable?

    /// A fixed wait before the component starts. Stacks with ``coalesce``.
    public var delay: Duration?

    /// The coalescing strategy applied before the component starts. See ``Coalesce``.
    public var coalesce: Coalesce?

    /// When `true`, cancel any existing component under ``id`` before starting this one
    /// (at most one concurrent run per id).
    public var exclusive: Bool

    /// Internal cancel-only sentinel: when `true`, the engine cancels ``id`` and starts nothing.
    /// Set only by ``Effect/cancelInFlight(id:)``. Will become a first-class cancel operation in a
    /// later stage of the effect-engine redesign.
    package var cancelsOnly: Bool

    /// A coalescing strategy applied to a component before it starts.
    public enum Coalesce: Sendable, Equatable {
        /// Wait `delay` of quiet before starting; each new arrival under the same id restarts the timer.
        case debounce(Duration)
        /// Run at most once per `interval`; arrivals inside the window are dropped.
        case throttle(Duration)
    }

    /// Creates a scheduling value from individual knobs. Prefer the named factories for the common cases.
    public init(
        id: AnyHashableSendable? = nil,
        delay: Duration? = nil,
        coalesce: Coalesce? = nil,
        exclusive: Bool = false
    ) {
        self.id = id
        self.delay = delay
        self.coalesce = coalesce
        self.exclusive = exclusive
        self.cancelsOnly = false
    }
}

// MARK: - Named factories

extension EffectScheduling {
    /// Start immediately with no cancellation tracking. Use for fire-and-forget work.
    public static var immediately: Self { .init() }

    /// Cancel any existing component under `id`, then start this one in its place (at most one run).
    public static func replacing(id: AnyHashableSendable) -> Self {
        .init(id: id, exclusive: true)
    }

    /// Cancel any pending component under `id`, then start a new one after `delay` of quiet.
    public static func debounce(id: AnyHashableSendable, delay: Duration) -> Self {
        .init(id: id, coalesce: .debounce(delay))
    }

    /// Start immediately under `id`, but only if no component with `id` ran within the last `interval`.
    public static func throttle(id: AnyHashableSendable, interval: Duration) -> Self {
        .init(id: id, coalesce: .throttle(interval))
    }

    /// Cancel-only scheduling for `id`: the engine cancels whatever is registered there and starts
    /// nothing. The ergonomic entry point is ``Effect/cancelInFlight(id:)``.
    public static func cancelInFlight(id: AnyHashableSendable) -> Self {
        var scheduling = Self(id: id)
        scheduling.cancelsOnly = true
        return scheduling
    }

    /// Returns a copy with a fixed pre-start ``delay``.
    public func delayed(by duration: Duration) -> Self {
        var copy = self
        copy.delay = duration
        return copy
    }
}

// MARK: - Generic id factories

// `AnyHashableSendable` satisfies `some Hashable & Sendable`, so without `@_disfavoredOverload` a
// call passing the wrapper (including the delegation inside each factory) would be ambiguous
// between the `AnyHashableSendable` factory and this one.

extension EffectScheduling {
    /// Creates a `replacing(id:)` policy from any `Hashable & Sendable` id.
    @_disfavoredOverload
    public static func replacing(id: some Hashable & Sendable) -> Self {
        .replacing(id: AnyHashableSendable(id))
    }

    /// Creates a `debounce(id:delay:)` policy from any `Hashable & Sendable` id.
    @_disfavoredOverload
    public static func debounce(id: some Hashable & Sendable, delay: Duration) -> Self {
        .debounce(id: AnyHashableSendable(id), delay: delay)
    }

    /// Creates a `throttle(id:interval:)` policy from any `Hashable & Sendable` id.
    @_disfavoredOverload
    public static func throttle(id: some Hashable & Sendable, interval: Duration) -> Self {
        .throttle(id: AnyHashableSendable(id), interval: interval)
    }

    /// Creates a `cancelInFlight(id:)` policy from any `Hashable & Sendable` id.
    @_disfavoredOverload
    public static func cancelInFlight(id: some Hashable & Sendable) -> Self {
        .cancelInFlight(id: AnyHashableSendable(id))
    }
}
