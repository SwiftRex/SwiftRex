import Foundation

/// Declares how the ``Store`` should schedule and manage the lifecycle of an ``Effect`` component.
///
/// Every `Effect` component carries an `EffectScheduling` value. The Store reads it after every
/// dispatch and decides whether to start the work immediately, delay it, deduplicate it, or cancel
/// an existing component. Neither ``Middleware`` nor ``Behavior`` execute these directives — they
/// are purely instructions to the Store.
///
/// ## Cancellation registry
///
/// Every case that carries an `id` shares a single `[AnyHashable: SubscriptionToken]` dictionary
/// inside the Store. A component registered under `"searchQuery"` can be cancelled by dispatching
/// `Effect.cancelInFlight(id: "searchQuery")`, regardless of whether it was originally debounced,
/// throttled, or replaced. There is no separate "make cancellable" step.
///
/// ## Choosing a policy
///
/// | Goal | Policy |
/// |---|---|
/// | Fire-and-forget, no cancellation | ``immediately`` |
/// | At most one concurrent run | ``replacing(id:)`` |
/// | Wait for quiet period (search-as-you-type) | ``debounce(id:delay:)`` |
/// | Rate-limit (scroll events, sensor data) | ``throttle(id:interval:)`` |
/// | Explicit cancel without replacement | ``cancelInFlight(id:)`` |
///
/// ```swift
/// // Debounce live search: reset the 300 ms timer on every keystroke
/// return .produce { env in
///     env.api.search(query).asEffect()
///         .scheduling(.debounce(id: "liveSearch", delay: 0.3))
/// }
///
/// // Throttle location updates to at most once every 5 seconds
/// return .produce { env in
///     env.gps.currentLocation().asEffect()
///         .scheduling(.throttle(id: "gps", interval: 5.0))
/// }
///
/// // Cancel any in-flight upload when the user taps "Discard"
/// case .discard:
///     return .produce { _ in .cancelInFlight(id: "upload") }
/// ```
///
/// - Note: `@unchecked Sendable` is used because `AnyHashable` does not formally conform to
///   `Sendable`. In practice, effect ids are always value types (strings, ints, enums) that
///   are safe to send across isolation boundaries.
public enum EffectScheduling: @unchecked Sendable {
    /// Start the component immediately with no cancellation tracking.
    ///
    /// Each `.immediately` component is registered under a freshly generated `UUID` key that is
    /// only used to clean up the dictionary entry when the component calls `complete`. There is
    /// no way to cancel an `.immediately` component after it has started.
    ///
    /// Use this for fire-and-forget work such as analytics events or one-shot notifications.
    case immediately

    /// Cancel any existing component registered under `id`, then start this one in its place.
    ///
    /// Unlike ``cancelInFlight(id:)`` which only removes the existing entry, `.replacing`
    /// starts a new component after cancelling the old one. This ensures there is always at most
    /// one component running under a given `id`.
    ///
    /// ```swift
    /// // Only the last-dispatched fetch runs; previous ones are cancelled
    /// return .produce { env in
    ///     env.api.fetchProfile().asEffect()
    ///         .scheduling(.replacing(id: "profileFetch"))
    /// }
    /// ```
    ///
    /// - Parameter id: The shared key in the Store's effect registry. Must be `Hashable`.
    case replacing(id: AnyHashable)

    /// Cancel any pending component with `id`, then start a new one after `delay` seconds.
    ///
    /// If another `.debounce` with the same `id` arrives before `delay` elapses, the timer
    /// resets and the previous pending work is cancelled. Only the component whose delay
    /// completes without interruption actually starts executing.
    ///
    /// Debounced components are also cancellable via ``cancelInFlight(id:)`` at any point —
    /// both during the delay and after the component has started.
    ///
    /// ```swift
    /// // Trigger a search no sooner than 300 ms after the last keystroke
    /// return .produce { env in
    ///     env.api.search(query).asEffect()
    ///         .scheduling(.debounce(id: "search", delay: 0.3))
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - id: The shared key in the Store's effect registry.
    ///   - delay: Seconds to wait after the latest dispatch before starting the component.
    case debounce(id: AnyHashable, delay: TimeInterval)

    /// Start the component immediately, but only if no component with `id` ran within the last
    /// `interval` seconds.
    ///
    /// When the interval has not elapsed since the last execution, the component is silently
    /// dropped — no work starts. When the interval has elapsed, the component starts and the
    /// timestamp is recorded for future throttle checks.
    ///
    /// Throttled components are cancellable via ``cancelInFlight(id:)`` while they are running.
    ///
    /// ```swift
    /// // Update the UI at most once every second when scrolling
    /// return .produce { env in
    ///     env.analytics.trackScroll(position).asEffect()
    ///         .scheduling(.throttle(id: "scroll", interval: 1.0))
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - id: The shared key in the Store's effect registry.
    ///   - interval: Minimum seconds between consecutive executions.
    case throttle(id: AnyHashable, interval: TimeInterval)

    /// Remove `id` from the registry and cancel whatever was registered there.
    ///
    /// This is a pure dictionary removal — no new component is started. It is the explicit,
    /// named-id counterpart to cancellation by token. Use it when the cancellation is a
    /// meaningful event (e.g., user taps "Cancel Upload") rather than a scheduling side-effect.
    ///
    /// ```swift
    /// case .cancelUpload:
    ///     return .produce { _ in .cancelInFlight(id: "upload") }
    /// ```
    ///
    /// - Parameter id: The shared key in the Store's effect registry to remove.
    case cancelInFlight(id: AnyHashable)
}
