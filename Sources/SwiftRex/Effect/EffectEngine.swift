import CoreFP
import Foundation
import Hourglass

/// The single scheduling engine shared by ``Store`` and `TestStore`.
///
/// It owns the effect registries and honours each component's ``EffectScheduling`` — cancel,
/// throttle, debounce/delay, replace, and the pipeable ``Effect/channel(value:scheduling:file:function:line:_:)``
/// path. The two substrate differences are injected, so both stores drive *identical* scheduling
/// logic with no duplication:
///
/// - `clock` — `ContinuousClock` in production; `ImmediateClock`/`TestClock` for deterministic tests.
/// - `send` — where produced actions go: the Store's `@MainActor` `process` hop, or the TestStore's
///   synchronous collection.
///
/// Delay timers re-enter the engine on `@MainActor` via `Task` + `clock.sleep`, so the engine is a
/// reference type (the timers mutate the registries on fire). ``SubscriptionToken`` cancels on
/// release, so releasing the engine cancels every in-flight effect — no explicit `deinit` needed.
@MainActor
package final class EffectEngine<Action: Sendable> {
    /// Running effects keyed by ``EffectScheduling/id`` (named) or a monotonic anonymous key. A
    /// channel stores its token here too (and its sink in `channelSinks`).
    private var runningEffects: [AnyHashableSendable: SubscriptionToken] = [:]

    /// Live value-sinks for running channels, keyed as `runningEffects`. Present iff a channel under
    /// that key is open; the engine pipes subsequent values through the sink instead of recreating.
    private var channelSinks: [AnyHashableSendable: @Sendable (any Sendable) -> Void] = [:]

    /// Pending debounce/delay timers for channel value delivery, kept *separate* from
    /// `runningEffects` so coalescing a value never tears down the live channel it pipes into.
    private var pendingDeliver: [AnyHashableSendable: SubscriptionToken] = [:]

    /// Last-fire instants for `.throttle` keys, paired with the interval so expired entries are pruned.
    private var throttleStamps: [AnyHashableSendable: (last: AnyClock<Swift.Duration>.Instant, interval: Duration)] = [:]

    /// Monotonic source of anonymous effect keys (internal, never surfaced).
    private var nextAnonymousEffectKey: UInt64 = 0

    /// The last desired-set this engine reconciled, keyed by channel id → its reset/broadcast identity
    /// pair. This is the *only* memory a state-driven `Reaction` needs: the reaction recomputes the full
    /// desired set each cycle and the engine diffs it against this, deriving open/recreate/pipe/cancel.
    private var reconciledStates: [AnyHashableSendable: ReconcileState] = [:]

    private let clock: AnyClock<Swift.Duration>
    private let send: @Sendable (DispatchedAction<Action>) -> Void

    package init(
        clock: AnyClock<Swift.Duration>,
        send: @escaping @Sendable (DispatchedAction<Action>) -> Void
    ) {
        self.clock = clock
        self.send = send
    }

    // MARK: - Inspection (used by TestStore for exhaustiveness)

    /// `true` when no one-shot effect is running and no channel-delivery timer is pending. Open
    /// channels are reported separately via ``openChannelKeys`` — a long-lived channel is *not*
    /// outstanding one-shot work, but it *is* an effect that must be cancelled before a test ends.
    package var isQuiescent: Bool { runningEffects.keys.allSatisfy { channelSinks[$0] != nil } && pendingDeliver.isEmpty }

    /// Keys of channels currently open. Exhaustive test mode fails if any remain at end-of-test.
    package var openChannelKeys: Set<AnyHashableSendable> { Set(channelSinks.keys) }

    // MARK: - Scheduling

    /// Distinct key type for anonymous (id-less) effects, so a `UInt64` counter value can never
    /// collide with a user-supplied `UInt64` id (``AnyHashableSendable`` equality is type-aware).
    private struct AnonymousEffectKey: Hashable, Sendable { let value: UInt64 }

    /// Honours a component's ``EffectScheduling``: cancels, throttles, debounces/delays, replaces,
    /// or starts it, routing produced actions back through `send`.
    package func schedule(_ component: Effect<Action>.Component) {
        let scheduling = component.scheduling

        // Cancel-only sentinel: remove the id and start nothing.
        if scheduling.cancelsOnly {
            if let id = scheduling.id { cancel(key: id) }
            return
        }

        // Named id, or a fresh anonymous key used only to clean up on completion.
        let key: AnyHashableSendable
        if let id = scheduling.id {
            key = id
        } else {
            nextAnonymousEffectKey &+= 1
            key = AnyHashableSendable(AnonymousEffectKey(value: nextAnonymousEffectKey))
        }

        // Pipeable channel: feed the value into the live effect (or start it) — never recreate.
        if let channel = component.channel {
            scheduleChannel(channel, key: key, scheduling: scheduling)
            return
        }

        // Throttle gate: drop entirely if a run happened within the interval.
        if case .throttle(let interval) = scheduling.coalesce {
            let now = clock.now
            throttleStamps = throttleStamps.filter { $0.value.last.duration(to: now) < $0.value.interval }
            if let entry = throttleStamps[key], entry.last.duration(to: now) < interval { return }
            throttleStamps[key] = (last: now, interval: interval)
        }

        // Any id-scoped policy (replace / debounce / throttle) supersedes the prior run under `key`.
        let debounceDelay: Duration?
        if case .debounce(let delay) = scheduling.coalesce { debounceDelay = delay } else { debounceDelay = nil }
        if scheduling.exclusive || scheduling.coalesce != nil {
            runningEffects[key]?.cancel()
        }

        // Total pre-start wait = debounce quiet period + fixed delay. Clamp negatives to zero.
        let preWait = max(.zero, (debounceDelay ?? .zero) + (scheduling.delay ?? .zero))
        let send = send

        if preWait > .zero {
            let clock = clock
            let task = Task { @MainActor [weak self] in
                try await clock.sleep(for: preWait)
                guard !Task.isCancelled, let self else { return }
                self.runningEffects[key] = component.subscribe(send) { [weak self] in
                    Task { @MainActor [weak self] in self?.runningEffects.removeValue(forKey: key) }
                }
            }
            runningEffects[key] = SubscriptionToken { task.cancel() }
        } else {
            runningEffects[key] = component.subscribe(send) { [weak self] in
                Task { @MainActor [weak self] in self?.runningEffects.removeValue(forKey: key) }
            }
        }
    }

    /// Honours scheduling for a pipeable channel: gates the *value delivery* (throttle drops,
    /// debounce/delay defers) and then pipes it into the live channel — starting the channel on
    /// first use — without ever tearing the running effect down.
    private func scheduleChannel(
        _ channel: Effect<Action>.Component.Channel,
        key: AnyHashableSendable,
        scheduling: EffectScheduling
    ) {
        // Throttle gate: drop this value if a delivery happened within the interval. The live
        // channel is untouched — only the value is dropped.
        if case .throttle(let interval) = scheduling.coalesce {
            let now = clock.now
            throttleStamps = throttleStamps.filter { $0.value.last.duration(to: now) < $0.value.interval }
            if let entry = throttleStamps[key], entry.last.duration(to: now) < interval { return }
            throttleStamps[key] = (last: now, interval: interval)
        }

        let debounceDelay: Duration?
        if case .debounce(let delay) = scheduling.coalesce { debounceDelay = delay } else { debounceDelay = nil }
        let preWait = max(.zero, (debounceDelay ?? .zero) + (scheduling.delay ?? .zero))
        let value = channel.value

        let deliver: @MainActor @Sendable () -> Void = { [weak self] in
            guard let self else { return }
            self.pendingDeliver.removeValue(forKey: key)
            if let sink = self.channelSinks[key] {
                sink(value)                         // a channel is live under this key → pipe into it
            } else if let start = channel.start {
                let (token, sink) = start(value, self.send) { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.runningEffects.removeValue(forKey: key)
                        self?.channelSinks.removeValue(forKey: key)
                    }
                }
                self.runningEffects[key] = token
                self.channelSinks[key] = sink
            }
            // else: pipe-only component (`start == nil`) and nothing live under this key → drop.
        }

        if preWait > .zero {
            // Restart the debounce window; the live channel (in `runningEffects`) is left running.
            pendingDeliver[key]?.cancel()
            let clock = clock
            let task = Task { @MainActor [weak self] in
                try await clock.sleep(for: preWait)
                guard !Task.isCancelled, self != nil else { return }
                deliver()
            }
            pendingDeliver[key] = SubscriptionToken { task.cancel() }
        } else {
            deliver()
        }
    }

    /// Cancels and forgets whatever runs under `key` across all registries (the cancel-only path,
    /// and the "no longer desired" path of ``reconcile(_:)``). A no-op if nothing is registered.
    ///
    /// Cancellation is driven by releasing the token (RAII `deinit`), not an explicit `cancel()` call:
    /// the token is sole-owned by `runningEffects`, so `removeValue` drops the last reference and
    /// cancels it **exactly once**. Calling `cancel()` *and* releasing would fire a side-effecting
    /// teardown (e.g. a channel's `socket.close()`) twice.
    private func cancel(key: AnyHashableSendable) {
        runningEffects.removeValue(forKey: key)
        channelSinks.removeValue(forKey: key)
        pendingDeliver.removeValue(forKey: key)
    }

    // MARK: - Reconcile (state-driven `Reaction`)

    /// A single desired `Channel` for one reconcile cycle.
    ///
    /// The `component`'s `scheduling.id` is the channel key — state-driven channels must be keyed
    /// (an unkeyed entry is skipped). Two identities drive the diff independently:
    /// - `resetIdentity` — the `ephemeral` reset key (`nil` = `permanent`). A change **recreates**
    ///   the channel (cancel + reopen).
    /// - `broadcastIdentity` — the `onChange` value (`nil` = `nothing`). A change **pipes** the new
    ///   value into the live channel.
    package struct ReconcileEntry: Sendable {
        package let component: Effect<Action>.Component
        package let resetIdentity: AnyHashableSendable?
        package let broadcastIdentity: AnyHashableSendable?

        package init(
            component: Effect<Action>.Component,
            resetIdentity: AnyHashableSendable?,
            broadcastIdentity: AnyHashableSendable?
        ) {
            self.component = component
            self.resetIdentity = resetIdentity
            self.broadcastIdentity = broadcastIdentity
        }
    }

    /// The reset/broadcast identity pair stored per key — the only memory a reconcile needs.
    private struct ReconcileState: Equatable, Sendable {
        let reset: AnyHashableSendable?
        let broadcast: AnyHashableSendable?
    }

    /// Reconciles the running channels against the **complete** `desired` set for this cycle:
    /// opens keys newly present, cancels keys now absent, recreates keys whose `resetIdentity`
    /// changed, and pipes keys whose `broadcastIdentity` changed. An unchanged desired set produces
    /// **zero** operations — the engine keeps the registry; the caller (a `Reaction`) keeps nothing.
    package func reconcile(_ desired: [ReconcileEntry]) {
        var next: [AnyHashableSendable: ReconcileState] = [:]
        next.reserveCapacity(desired.count)
        for entry in desired {
            guard let key = entry.component.scheduling.id else { continue }
            let state = ReconcileState(reset: entry.resetIdentity, broadcast: entry.broadcastIdentity)
            next[key] = state
            if let prev = reconciledStates[key] {
                if prev.reset != state.reset {
                    cancel(key: key)            // recreate: tear down, then reopen below
                    schedule(entry.component)
                } else if prev.broadcast != state.broadcast {
                    schedule(entry.component)   // pipe: deliver the new value into the live channel
                }
                // else: both unchanged → nothing
            } else {
                schedule(entry.component)        // newly present → open
            }
        }
        for key in reconciledStates.keys where next[key] == nil { cancel(key: key) }
        reconciledStates = next
    }
}
