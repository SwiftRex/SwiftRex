import CoreFP
import Foundation
import Hourglass
@testable import SwiftRex
import Testing

// MARK: - Pipeable channel effects (Effect.channel)

@Suite("Store channel effects")
@MainActor
struct StoreChannelTests {
    private enum A: Sendable, Equatable {
        case write(Int)
        case received(Int)
        case close
    }

    /// Drains `@MainActor` `Task` hops until `condition` holds or a bounded number of yields elapse.
    private func poll(until condition: @MainActor () -> Bool) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
    }

    @Test func channelOpensOnceAndPipesEverySubsequentValue() async {
        let starts = LockProtected(0)
        let received = LockProtected([Int]())
        let store = Store(
            initial: 0,
            behavior: Behavior<A, Int, Void>.handle { action, _ in
                switch action {
                case .write(let n):
                    .produce { _ in
                        .channel(value: n, scheduling: .replacing(id: "socket")) { _, _ in
                            starts.mutate { $0 += 1 }
                            return ChannelHandler(receive: { v in received.mutate { $0.append(v) } }, cancel: {})
                        }
                    }
                default:
                    .doNothing
                }
            },
            environment: ()
        )
        store.dispatch(.write(1))
        store.dispatch(.write(2))
        store.dispatch(.write(3))
        await poll { received.value.count == 3 }
        #expect(starts.value == 1)              // opened exactly once — not recreated
        #expect(received.value == [1, 2, 3])    // every value piped into the same live channel
    }

    @Test func channelEmitsActionsBackThroughSend() async {
        let store = Store(
            initial: 0,
            behavior: Behavior<A, Int, Void>.handle { action, _ in
                switch action {
                case .write(let n):
                    .produce { _ in
                        .channel(value: n, scheduling: .replacing(id: "socket")) { send, _ in
                            ChannelHandler(receive: { v in send(.received(v)) }, cancel: {})
                        }
                    }
                case .received(let v):
                    .reduce { $0 += v }
                case .close:
                    .doNothing
                }
            },
            environment: ()
        )
        store.dispatch(.write(10))
        await poll { store.state == 10 }
        store.dispatch(.write(5))               // piped into the same channel → send(.received(5))
        await poll { store.state == 15 }
        #expect(store.state == 15)
    }

    @Test func throttleGatesValuesWithoutTearingDownTheChannel() async {
        let clock = TestClock()
        let starts = LockProtected(0)
        let received = LockProtected([Int]())
        let store = Store(
            initial: 0,
            behavior: Behavior<A, Int, Void>.handle { action, _ in
                switch action {
                case .write(let n):
                    .produce { _ in
                        .channel(value: n, scheduling: .throttle(id: "socket", interval: .seconds(1))) { _, _ in
                            starts.mutate { $0 += 1 }
                            return ChannelHandler(receive: { v in received.mutate { $0.append(v) } }, cancel: {})
                        }
                    }
                default:
                    .doNothing
                }
            },
            environment: (),
            clock: { _ in clock }
        )
        store.dispatch(.write(1))               // opens + delivers 1
        await poll { received.value == [1] }
        store.dispatch(.write(2))               // within interval → value dropped, channel stays open
        for _ in 0..<20 { await Task.yield() }
        #expect(received.value == [1])
        #expect(starts.value == 1)
        await clock.advance(by: .seconds(1))    // interval elapses
        store.dispatch(.write(3))               // delivered into the SAME live channel
        await poll { received.value == [1, 3] }
        #expect(starts.value == 1)              // never recreated across the throttle
    }

    @Test func debounceDeliversLatestValueIntoTheLiveChannel() async {
        let clock = TestClock()
        let starts = LockProtected(0)
        let received = LockProtected([Int]())
        let store = Store(
            initial: 0,
            behavior: Behavior<A, Int, Void>.handle { action, _ in
                switch action {
                case .write(let n):
                    .produce { _ in
                        .channel(value: n, scheduling: .debounce(id: "socket", delay: .seconds(1))) { _, _ in
                            starts.mutate { $0 += 1 }
                            return ChannelHandler(receive: { v in received.mutate { $0.append(v) } }, cancel: {})
                        }
                    }
                default:
                    .doNothing
                }
            },
            environment: (),
            clock: { _ in clock }
        )
        store.dispatch(.write(1))
        await clock.waitForSleepers()
        store.dispatch(.write(2))               // resets the debounce window
        await clock.waitForSleepers()
        await clock.advance(by: .seconds(1))
        await poll { received.value == [2] }    // collapsed to the latest value
        #expect(received.value == [2])
        #expect(starts.value == 1)
    }

    @Test func cancelInFlightTearsDownTheChannel() async {
        let cancelled = LockProtected(false)
        let received = LockProtected([Int]())
        let store = Store(
            initial: 0,
            behavior: Behavior<A, Int, Void>.handle { action, _ in
                switch action {
                case .write(let n):
                    .produce { _ in
                        .channel(value: n, scheduling: .replacing(id: "socket")) { _, _ in
                            ChannelHandler(
                                receive: { v in received.mutate { $0.append(v) } },
                                cancel: { cancelled.set(true) }
                            )
                        }
                    }
                case .close:
                    .produce { _ in .cancelInFlight(id: "socket") }
                case .received:
                    .doNothing
                }
            },
            environment: ()
        )
        store.dispatch(.write(1))
        await poll { received.value == [1] }
        store.dispatch(.close)                  // cancelInFlight(id: "socket")
        await poll { cancelled.value }
        #expect(cancelled.value)
    }

    @Test func mapCarriesTheChannel() {
        let effect = Effect<Int>.channel(value: 7, scheduling: .replacing(id: "x")) { _, _ in
            ChannelHandler(receive: { _ in }, cancel: {})
        }
        #expect(effect.components.first?.channel != nil)
        #expect(effect.map(String.init).components.first?.channel != nil)
    }
}
