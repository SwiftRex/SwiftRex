import CoreFP
import DataStructure
import Foundation
import Hourglass

/// Drives the lifecycle of scheduled ``Effect`` components — starting, delaying, coalescing
/// (debounce/throttle), replacing, and cancelling them — keyed by ``EffectScheduling/id`` in a
/// shared registry.
///
/// Extracted from `Store` so one engine owns all the mutable scheduling state (`@MainActor`-only)
/// and can be reused by both the action-driven path today and the state-driven reconciler later.
/// Produced actions are routed to the `send` closure supplied per ``apply(_:send:)`` call.
@MainActor
final class EffectScheduler<Action: Sendable> {
    /// Running effects keyed by id (named) or a fresh anonymous key. Each ``SubscriptionToken``
    /// cancels its effect when released, so removing/replacing an entry cancels the in-flight work.
    private var effects: [AnyHashableSendable: SubscriptionToken] = [:]

    /// Last-fire instants for throttle keys, paired with the interval so expired entries can be
    /// pruned — keeps the dictionary bounded under unbounded distinct keys.
    private var throttleTimestamps: [AnyHashableSendable: (last: AnyClock<Swift.Duration>.Instant, interval: Duration)] = [:]

    /// Clock for all timing (debounce/delay sleep, throttle window). Injected; erased to `AnyClock`.
    private let clock: AnyClock<Swift.Duration>

    /// Randomness for anonymous keys, threaded through ``idGen``. Only mutated on `@MainActor`.
    private var rng: AnyRandomNumberGenerator

    /// Pure recipe turning ``rng`` into anonymous registry keys — the `Gen`-based `UUID()` replacement.
    private let idGen = Gen<UUID>.uuid()

    init(clock: AnyClock<Swift.Duration>, rng: AnyRandomNumberGenerator) {
        self.clock = clock
        self.rng = rng
    }

    /// Schedules `component` per its ``EffectScheduling``, routing produced actions to `send`.
    func apply(
        _ component: Effect<Action>.Component,
        send: @escaping @Sendable (DispatchedAction<Action>) -> Void
    ) {
        let scheduling = component.scheduling

        // Cancel-only sentinel: remove the id and start nothing.
        if scheduling.cancelsOnly {
            if let id = scheduling.id {
                effects[id]?.cancel()
                effects.removeValue(forKey: id)
            }
            return
        }

        // Named id, or a fresh anonymous key used only to clean up on completion.
        let key = scheduling.id ?? AnyHashableSendable(idGen(&rng))

        // Throttle gate: drop entirely if a run happened within the interval.
        if case .throttle(let interval) = scheduling.coalesce {
            let now = clock.now
            throttleTimestamps = throttleTimestamps.filter { $0.value.last.duration(to: now) < $0.value.interval }
            if let entry = throttleTimestamps[key], entry.last.duration(to: now) < interval { return }
            throttleTimestamps[key] = (last: now, interval: interval)
        }

        // Any id-scoped policy (replace / debounce / throttle) supersedes the prior run under `key`.
        let debounceDelay: Duration?
        if case .debounce(let delay) = scheduling.coalesce { debounceDelay = delay } else { debounceDelay = nil }
        if scheduling.exclusive || scheduling.coalesce != nil {
            effects[key]?.cancel()
        }

        // Total pre-start wait = debounce quiet period + fixed delay. Clamp negatives to zero.
        let preWait = max(.zero, (debounceDelay ?? .zero) + (scheduling.delay ?? .zero))

        if preWait > .zero {
            let clock = clock
            let task = Task { @MainActor [weak self] in
                try await clock.sleep(for: preWait)
                guard !Task.isCancelled, let self else { return }
                self.effects[key] = component.subscribe(send) { [weak self] in
                    Task { @MainActor [weak self] in self?.effects.removeValue(forKey: key) }
                }
            }
            effects[key] = SubscriptionToken { task.cancel() }
        } else {
            effects[key] = component.subscribe(send) { [weak self] in
                Task { @MainActor [weak self] in self?.effects.removeValue(forKey: key) }
            }
        }
    }
}
