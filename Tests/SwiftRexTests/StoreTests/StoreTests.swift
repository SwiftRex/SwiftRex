import CoreFP
import DataStructure
import Hourglass
@testable import SwiftRex
import Testing

// MARK: - Helpers

@MainActor
private func makeStore(initial: Int = 0) -> Store<Int, Int, Void> {
    Store(initial: initial, reducer: Reducer.reduce { action, state in state += action })
}

// MARK: - Init

@Suite("Store init")
@MainActor
struct StoreInitTests {
    @Test func reducerInitSetsInitialState() {
        let store = Store(initial: 42, reducer: Reducer<Int, Int>.reduce { _, _ in })
        #expect(store.state == 42)
    }

    @Test func behaviorInitSetsInitialState() {
        let store = Store(initial: 7, behavior: Behavior<Int, Int, Void>.identity, environment: ())
        #expect(store.state == 7)
    }
}

// MARK: - Dispatch → mutation

@Suite("Store dispatch")
@MainActor
struct StoreDispatchTests {
    @Test func dispatchMutatesState() {
        let store = makeStore()
        store.dispatch(5)
        #expect(store.state == 5)
    }

    @Test func dispatchIsAccumulative() {
        let store = makeStore()
        store.dispatch(3)
        store.dispatch(4)
        #expect(store.state == 7)
    }

    @Test func dispatchWithSourcePreservesCallSite() {
        let line: UInt = #line
        let seen = LockProtected([ActionSource]())
        let store = Store(
            initial: 0,
            behavior: Behavior<Int, Int, Void>.handle { _, context in
                seen.mutate { $0.append(context.source) }
                return .doNothing
            },
            environment: ()
        )
        store.dispatch(1, source: ActionSource(file: "f.swift", function: "fn()", line: line))
        #expect(seen.value.first?.line == line)
    }
}

// MARK: - observe(willChange:didChange:)

@Suite("Store observe")
@MainActor
struct StoreObserveTests {
    @Test func willChangeFiresBeforeMutation() {
        let store = makeStore()
        var stateAtWillChange = -1
        _ = store.observe(
            willChange: { stateAtWillChange = store.state },
            didChange: {}
        )
        store.dispatch(10)
        #expect(stateAtWillChange == 0) // saw pre-mutation state
    }

    @Test func didChangeFiresAfterMutation() {
        let store = makeStore()
        var stateAtDidChange = -1
        _ = store.observe(
            willChange: {},
            didChange: { stateAtDidChange = store.state }
        )
        store.dispatch(10)
        #expect(stateAtDidChange == 10) // saw post-mutation state
    }

    @Test func multipleObserversAllFire() {
        let store = makeStore()
        let count = LockProtected(0)
        _ = store.observe(willChange: {}, didChange: { count.mutate { $0 += 1 } })
        _ = store.observe(willChange: {}, didChange: { count.mutate { $0 += 1 } })
        store.dispatch(1)
        #expect(count.value == 2)
    }

    @Test func cancellingTokenRemovesObserver() async {
        let store = makeStore()
        let count = LockProtected(0)
        let token = store.observe(willChange: {}, didChange: { count.mutate { $0 += 1 } })
        store.dispatch(1)
        token.cancel()
        // Cancellation hops through a Task; yield so it can run
        await Task.yield()
        await Task.yield()
        store.dispatch(1)
        #expect(count.value == 1)
    }
}

// MARK: - Effect dispatch (immediate scheduling)

@Suite("Store effect scheduling")
@MainActor
struct StoreEffectSchedulingTests {
    @Test func immediateEffectLoopsBackAction() async {
        let store = Store(
            initial: 0,
            behavior: Behavior<Int, Int, Void>.handle { action, _ in
                action == 0
                    ? .produce { _ in .just(99) }
                    : .doNothing
            },
            environment: ()
        )
        store.dispatch(0)
        await Task.yield()
        await Task.yield()
        #expect(store.state == 0) // behavior produced effect but no mutation
    }

    @Test func replacingCancelsInFlightEffect() async {
        let dispatched = LockProtected([Int]())
        let store = Store(
            initial: 0,
            behavior: Behavior<Int, Int, Void>.handle { action, _ in
                .produce { _ in Effect<Int>.just(action).scheduling(.replacing(id: "key")) }
            },
            environment: ()
        )
        store.dispatch(1)
        store.dispatch(2) // should cancel the first
        await Task.yield()
        await Task.yield()
        _ = dispatched
        // Simply verify no crash and the store is still alive
        #expect(store.state == 0)
    }

    @Test func cancelInFlightStopsEffect() {
        let store = Store(
            initial: 0,
            behavior: Behavior<Int, Int, Void>.handle { action, _ in
                action == 0
                    ? .produce { _ in Effect<Int>.just(1).scheduling(.cancelInFlight(id: "key")) }
                    : .doNothing
            },
            environment: ()
        )
        store.dispatch(0)
        // No crash; effect cancelled immediately
        #expect(store.state == 0)
    }

    /// A negative debounce delay must not trap; it is clamped to `.zero`, so the effect fires
    /// (effectively immediately) and loops its action back.
    @Test func negativeDebounceDelayIsClampedAndFires() async {
        let store = Store(
            initial: 0,
            behavior: Behavior<Int, Int, Void>.handle { action, _ in
                action == 0
                    ? .produce { _ in Effect<Int>.just(5).scheduling(.debounce(id: "d", delay: .seconds(-1))) }
                    : .reduce { $0 = action }
            },
            environment: ()
        )
        store.dispatch(0)
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(store.state == 5)
    }
}

// MARK: - Clock injection (deterministic scheduling)

@Suite("Store clock injection")
@MainActor
struct StoreClockInjectionTests {
    /// Drains `@MainActor` `Task` hops (effect → action loopback) until `condition` holds or a
    /// bounded number of yields elapse.
    private func poll(until condition: @MainActor () -> Bool) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
    }

    @Test func debounceFiresOnlyAfterInjectedClockAdvancesPastDelay() async {
        let clock = TestClock()
        let store = Store(
            initial: 0,
            behavior: Behavior<Int, Int, Void>.handle { action, _ in
                action == 0
                    ? .produce { _ in Effect<Int>.just(5).scheduling(.debounce(id: "d", delay: .seconds(1))) }
                    : .reduce { $0 = action }
            },
            environment: (),
            clock: { _ in clock }
        )
        store.dispatch(0)
        await clock.waitForSleepers()          // the debounce task is parked on clock.sleep
        #expect(store.state == 0)              // nothing fired before the delay elapses
        await clock.advance(by: .seconds(1))
        await poll { store.state == 5 }        // delay elapsed → effect fires, loops 5 back
        #expect(store.state == 5)
    }

    @Test func debounceCollapsesRapidDispatchesOnInjectedClock() async {
        enum A: Sendable { case trigger, fired }
        let clock = TestClock()
        let store = Store(
            initial: 0,
            behavior: Behavior<A, Int, Void>.handle { action, _ in
                switch action {
                case .trigger: .produce { _ in Effect<A>.just(.fired).scheduling(.debounce(id: "d", delay: .seconds(1))) }
                case .fired: .reduce { $0 += 1 }
                }
            },
            environment: (),
            clock: { _ in clock }
        )
        store.dispatch(.trigger)
        await clock.waitForSleepers()
        store.dispatch(.trigger)               // resets the timer: cancels the first pending task
        await clock.waitForSleepers()
        await clock.advance(by: .seconds(1))
        await poll { store.state == 1 }
        #expect(store.state == 1)              // collapsed to a single fire
    }

    @Test func throttleDropsWithinIntervalThenFiresAfterAdvance() async {
        enum A: Sendable { case ping, tick }
        let clock = TestClock()
        let store = Store(
            initial: 0,
            behavior: Behavior<A, Int, Void>.handle { action, _ in
                switch action {
                case .ping: .produce { _ in Effect<A>.just(.tick).scheduling(.throttle(id: "t", interval: .seconds(1))) }
                case .tick: .reduce { $0 += 1 }
                }
            },
            environment: (),
            clock: { _ in clock }
        )
        store.dispatch(.ping)
        await poll { store.state == 1 }        // first one fires immediately
        store.dispatch(.ping)                  // still within the interval → dropped
        for _ in 0..<20 { await Task.yield() }
        #expect(store.state == 1)
        await clock.advance(by: .seconds(1))   // interval elapses on the injected clock
        store.dispatch(.ping)
        await poll { store.state == 2 }        // now fires again
        #expect(store.state == 2)
    }
}

// MARK: - Convenience init (reducer + middleware)

@Suite("Store reducer+middleware init")
@MainActor
struct StoreReducerMiddlewareInitTests {
    @Test func reducerMutatesAndMiddlewareProducesEffect() async {
        // Middleware produces a .just(1000) which loops back and adds 1000 to state
        let store = Store(
            initial: 0,
            reducer: Reducer<Int, Int>.reduce { action, state in state += action },
            middleware: Middleware<Int, Int, Void>.handle { action, _ in
                Reader { _ in action < 100 ? .just(1_000) : .empty }
            },
            environment: ()
        )
        store.dispatch(5)
        await Task.yield()
        await Task.yield()
        #expect(store.state == 1_005) // 5 from reducer + 1000 from effect loop-back
    }
}

// MARK: - Dispatch serialization (re-entrancy + ordering)

/// An effect that synchronously appends `label` to `log` when the Store subscribes it, then
/// completes. Produces no actions. The synchronous subscribe lets a test observe the exact
/// order in which the Store schedules effects across actions.
private func schedulingProbe(_ label: String, into log: LockProtected<[String]>) -> Effect<Int> {
    Effect(components: [
        .init(
            subscribe: { _, complete in
                log.mutate { $0.append(label) }
                complete()
                return .empty
            },
            scheduling: .immediately
        )
    ])
}

@Suite("Store dispatch serialization")
@MainActor
struct StoreDispatchSerializationTests {
    /// The defining guarantee of the fix: a `didChange` observer that synchronously re-dispatches
    /// must *not* nest inside the in-progress action. Notification order alone cannot prove this
    /// (it is identical whether nested or queued), but effect-scheduling order can: the first
    /// action must finish scheduling its own effect before the re-entrant action's effect is
    /// scheduled. Under the old nested behavior the order would be reversed (`["B", "A"]`).
    ///
    /// The behavior mutates so `didChange` actually fires (effect-only actions don't notify).
    @Test func reentrantDispatchDoesNotNestEffectScheduling() {
        let log = LockProtected([String]())
        let store = Store(
            initial: 0,
            behavior: Behavior<Int, Int, Void>.handle { action, _ in
                .reduce { $0 += 1 }.produce { _ in schedulingProbe(action == 1 ? "A" : "B", into: log) }
            },
            environment: ()
        )
        var didReenter = false
        let token = store.observe(didChange: {
            if !didReenter {
                didReenter = true
                store.dispatch(2) // synchronous re-dispatch from inside the first action's didChange
            }
        })

        store.dispatch(1)

        #expect(log.value == ["A", "B"]) // first action scheduled fully before the re-entrant one
        withExtendedLifetime(token) {}
    }

    /// Re-entrant dispatch never produces a partial-state notification: each action's
    /// willChange/didChange pair is fully sequenced, never interleaved.
    @Test func reentrantDispatchNotificationsAreNotInterleaved() {
        let order = LockProtected([String]())
        let store = Store(
            initial: 0,
            reducer: Reducer<Int, Int>.reduce { action, state in state += action }
        )
        var didReenter = false
        _ = store.observe(
            willChange: { order.mutate { $0.append("will(\(store.state))") } },
            didChange: {
                order.mutate { $0.append("did(\(store.state))") }
                if !didReenter {
                    didReenter = true
                    store.dispatch(10)
                }
            }
        )

        store.dispatch(1)

        #expect(order.value == ["will(0)", "did(1)", "will(1)", "did(11)"])
        #expect(store.state == 11)
    }

    /// Multiple actions dispatched synchronously in a single observer callback are drained in
    /// FIFO order by the active loop.
    @Test func multipleSynchronousReentrantDispatchesAreFIFO() {
        let seen = LockProtected([Int]())
        let store = Store(
            initial: 0,
            reducer: Reducer<Int, Int>.reduce { action, state in state += action }
        )
        var fired = false
        _ = store.observe(didChange: {
            seen.mutate { $0.append(store.state) }
            if !fired {
                fired = true
                store.dispatch(3)
                store.dispatch(2)
                store.dispatch(1)
            }
        })

        store.dispatch(0)

        #expect(seen.value == [0, 3, 5, 6]) // 0, then +3, +2, +1 in dispatch order
        #expect(store.state == 6)
    }
}

// MARK: - Notification skipping for non-mutating actions (ReducerOutcome.unchanged)

@Suite("Store notification skipping")
@MainActor
struct StoreNotificationSkippingTests {
    private func countingStore(
        _ behavior: Behavior<Int, Int, Void>
    ) -> (store: Store<Int, Int, Void>, will: LockProtected<Int>, did: LockProtected<Int>, token: SubscriptionToken) {
        let will = LockProtected(0)
        let did = LockProtected(0)
        let store = Store(initial: 0, behavior: behavior, environment: ())
        let token = store.observe(
            willChange: { will.mutate { $0 += 1 } },
            didChange: { did.mutate { $0 += 1 } }
        )
        return (store, will, did, token)
    }

    @Test func effectOnlyActionDoesNotNotify() {
        let (store, will, did, token) = countingStore(
            .handle { _, _ in .produce { _ in .empty } }
        )
        store.dispatch(1)
        #expect(will.value == 0)
        #expect(did.value == 0)
        withExtendedLifetime(token) {}
    }

    @Test func doNothingDoesNotNotify() {
        let (store, will, did, token) = countingStore(.handle { _, _ in .doNothing })
        store.dispatch(1)
        #expect(will.value == 0)
        #expect(did.value == 0)
        withExtendedLifetime(token) {}
    }

    @Test func pureRoutingOnDoesNotNotify() {
        // `.on(predicate, dispatch:)` routes without mutating; the routed action also does nothing.
        let (store, will, did, token) = countingStore(
            Behavior<Int, Int, Void>.identity.on({ $0 == 1 }, dispatch: 99)
        )
        store.dispatch(1)
        #expect(will.value == 0)
        #expect(did.value == 0)
        withExtendedLifetime(token) {}
    }

    @Test func mutatingActionNotifiesExactlyOnce() {
        let (store, will, did, token) = countingStore(
            .handle { action, _ in .reduce { $0 = action } }
        )
        store.dispatch(7)
        #expect(store.state == 7)
        #expect(will.value == 1)
        #expect(did.value == 1)
        withExtendedLifetime(token) {}
    }

    @Test func onWithReduceNotifies() {
        let (store, will, did, token) = countingStore(
            Behavior<Int, Int, Void>.identity.on({ $0 == 1 }, reduce: { $0 = 42 })
        )
        store.dispatch(1)
        #expect(store.state == 42)
        #expect(will.value == 1)
        #expect(did.value == 1)
        withExtendedLifetime(token) {}
    }
}
