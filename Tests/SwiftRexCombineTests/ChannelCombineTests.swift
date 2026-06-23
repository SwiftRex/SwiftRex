#if canImport(Combine)
import Combine
import SwiftRex
@testable import SwiftRexCombine
import Testing

// MARK: - Publisher.asChannel — a long-lived subscription driven by a real Store's supervise axis,
// with the spotlight on subscription-time timing.

@Suite("Channel+Combine: Publisher.asChannel")
@MainActor
struct ChannelCombineTests {
    /// Test-only Sendable box: a Combine subject isn't `Sendable`, but here it's only ever touched on
    /// `@MainActor`, so wrapping it is safe and keeps it usable as the Store's `Environment`.
    private final class Feed: @unchecked Sendable {
        let subject: CurrentValueSubject<Int, Never>
        init(_ initial: Int) { subject = .init(initial) }
    }

    private struct S: Sendable, Equatable {
        var subscribed = false
        var received: [Int] = []
    }

    private enum A: Sendable, Equatable {
        case subscribe, unsubscribe
        case got(Int)
    }

    private let reducer = Behavior<A, S, Feed>.handle { action, _ in
        switch action {
        case .subscribe: .reduce { $0.subscribed = true }
        case .unsubscribe: .reduce { $0.subscribed = false }
        case .got(let v): .reduce { $0.received.append(v) }
        }
    }

    private func poll(until condition: @MainActor () -> Bool) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
    }

    /// A `CurrentValueSubject` emits its current value **synchronously on subscribe** — inside the
    /// channel body, while the engine is still mid-reconcile. It must be delivered exactly once and
    /// only after the channel is registered (never lost, never doubled, never re-entrant).
    @Test func synchronousEmissionIsDeliveredOnceAfterSetup() async {
        let feed = Feed(1)
        let supervisor = Behavior<A, S, Feed>.supervise { state in
            Keep { env in state.subscribed ? [env.subject.asChannel(id: "feed", A.got)] : [] }
        }
        let store = Store(initial: S(), behavior: .combine(reducer, supervisor), environment: feed)

        #expect(store.state.received.isEmpty)            // not subscribed yet → no channel, no value

        store.dispatch(.subscribe)                       // opens the channel; subject emits 1 synchronously
        await poll { store.state.received == [1] }
        #expect(store.state.received == [1])             // the sync emission landed exactly once

        feed.subject.send(2)                             // ongoing emissions flow through the live channel
        feed.subject.send(3)
        await poll { store.state.received == [1, 2, 3] }
        #expect(store.state.received == [1, 2, 3])
    }

    /// Leaving the implying state cancels the `AnyCancellable`; later emissions are not delivered.
    @Test func cancellingTheChannelTearsDownTheSubscription() async {
        let feed = Feed(0)
        let supervisor = Behavior<A, S, Feed>.supervise { state in
            Keep { env in state.subscribed ? [env.subject.asChannel(id: "feed", A.got)] : [] }
        }
        let store = Store(initial: S(), behavior: .combine(reducer, supervisor), environment: feed)

        store.dispatch(.subscribe)
        await poll { store.state.received == [0] }

        store.dispatch(.unsubscribe)                     // desired set empties → channel cancelled
        await poll { !store.state.subscribed }
        feed.subject.send(99)                            // arrives after teardown
        for _ in 0..<20 { await Task.yield() }
        #expect(store.state.received == [0])             // 99 never delivered — subscription was cancelled
    }
}
#endif
