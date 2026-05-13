import Foundation

/// Declares how the Store should schedule and manage the lifecycle of an `Effect` component.
///
/// The Store interprets these directives — Middleware and ActionHandler never execute them directly.
///
/// **Cancellation:** every case that carries an `id` shares the same cancellation registry in the
/// Store. Dispatching `Effect.cancelInFlight(id: myId)` cancels whatever is registered under
/// `myId` — a pending debounce timer, a throttled effect, or a plain cancellable task. You do
/// not need a separate `.cancellable` wrapper to make a debounced or throttled effect cancellable.
///
/// `@unchecked Sendable` because `AnyHashable` does not formally conform to `Sendable` (it wraps
/// any `Hashable` value and cannot statically prove safety), but in practice effect ids are always
/// value types (strings, ints, enums) which are safe to send across boundaries.
public enum EffectScheduling: @unchecked Sendable {
    /// Run immediately. No cancellation tracking.
    case immediately

    /// Cancel any existing effect registered under `id`, then run this one and register it
    /// as the new value. Contrast with `cancelInFlight` which removes the key without replacing.
    case replacing(id: AnyHashable)

    /// Cancel any pending timer or running effect with the same `id`, then start a new one
    /// after `delay` seconds. If another debounce with the same `id` arrives before `delay`
    /// elapses, the timer resets. Also cancellable via `cancelInFlight(id:)`.
    case debounce(id: AnyHashable, delay: TimeInterval)

    /// Run immediately, but only if no effect with the same `id` ran within the last `interval`
    /// seconds. Also cancellable via `cancelInFlight(id:)`.
    case throttle(id: AnyHashable, interval: TimeInterval)

    /// Remove the key `id` from the registry, cancelling whatever was registered there.
    /// No new effect is started — this is a pure dictionary removal, not a replace.
    case cancelInFlight(id: AnyHashable)
}
