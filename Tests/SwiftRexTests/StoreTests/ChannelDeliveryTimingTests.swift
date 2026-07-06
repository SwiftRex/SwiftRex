// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure
import Hourglass
@testable import SwiftRex
import Testing

// MARK: - The prototype: creation is decoupled from delivery pacing, and `settle` debounces creation.

//
// Two orthogonal knobs:
//   • `ChannelDelivery` (.throttle/.debounce) paces the *values* flowing into a live channel — the
//     channel acting as a throttled subject. Creation is never deferred.
//   • `Lifetime.ephemeral(resetKey:settle:)` debounces *creation* — a key change tears the live
//     instance down immediately and reopens only once the key is quiet, with the latest value winning.

@Suite("Channel delivery timing + settle")
@MainActor
struct ChannelDeliveryTimingTests {
    private func poll(until condition: @MainActor () -> Bool) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
    }

    // MARK: - Permanent channels pace delivery, open immediately

    private struct Feed: Sendable, Equatable {
        var connected = false
        var tick = 0
        var received: [Int] = []
    }

    private enum FeedAction: Sendable, Equatable {
        case connect, bump
        case got(Int)
    }

    private let feedReducer = Behavior<FeedAction, Feed, Void>.handle { action, _ in
        switch action {
        case .connect: .reduce { $0.connected = true }
        case .bump: .reduce { $0.tick += 1 }
        case let .got(v): .reduce { $0.received.append(v) }
        }
    }

    private func feedStore(_ delivery: ChannelDelivery, clock: TestClock, opens: LockProtected<Int>) -> Store<FeedAction, Feed, Void> {
        let supervisor = Behavior<FeedAction, Feed, Void>.supervise { state in
            Supervision { _ in
                guard state.connected else { return [] }
                return [
                    Channel(id: "feed", broadcasting: .onChange(state.tick), delivery: delivery) { dispatch in
                        opens.mutate { $0 += 1 }
                        return ChannelHandler(receive: { dispatch(.got($0)) }, cancel: {})
                    }
                ]
            }
        }
        return Store(initial: Feed(), behavior: .combine(feedReducer, supervisor), environment: (), clock: { _ in clock })
    }

    @Test func throttleDeliveryOpensImmediatelyThenPacesValues() async {
        let clock = TestClock()
        let opens = LockProtected(0)
        let store = feedStore(.throttle(.seconds(1)), clock: clock, opens: opens)

        store.dispatch(.connect) // opens NOW — the throttle never defers creation
        await poll { opens.value == 1 && store.state.received == [0] }
        #expect(opens.value == 1)
        #expect(store.state.received == [0]) // the open's current value delivered immediately

        store.dispatch(.bump) // tick 1, inside the throttle window → dropped
        for _ in 0..<20 {
            await Task.yield()
        }
        #expect(store.state.received == [0])

        await clock.advance(by: .seconds(1)) // window elapses
        store.dispatch(.bump) // tick 2 → delivered into the SAME live channel
        await poll { store.state.received == [0, 2] }
        #expect(opens.value == 1) // never reopened across the throttle
    }

    @Test func debounceDeliveryCollapsesValuesButKeepsTheChannel() async {
        let clock = TestClock()
        let opens = LockProtected(0)
        let store = feedStore(.debounce(.seconds(1)), clock: clock, opens: opens)

        store.dispatch(.connect) // opens + delivers the current value immediately
        await poll { store.state.received == [0] }

        store.dispatch(.bump) // tick 1, debounced…
        store.dispatch(.bump) // tick 2, restarts the window → only the latest survives
        await clock.waitForSleepers()
        await clock.advance(by: .seconds(1))
        await poll { store.state.received == [0, 2] }
        #expect(store.state.received == [0, 2])
        #expect(opens.value == 1)
    }

    // MARK: - Ephemeral `settle` debounces creation (kill now, recreate later)

    private struct Search: Sendable, Equatable { var query = "" }
    private enum SearchAction: Sendable, Equatable { case setQuery(String) }

    @Test func settleDefersCreationAndTearsTheStaleInstanceDownImmediately() async {
        let clock = TestClock()
        let opens = LockProtected([String]())
        let cancels = LockProtected(0)
        let reducer = Behavior<SearchAction, Search, Void>.handle { action, _ in
            switch action {
            case let .setQuery(q): .reduce { $0.query = q }
            }
        }
        let supervisor = Behavior<SearchAction, Search, Void>.supervise { state in
            Supervision { _ in
                guard !state.query.isEmpty else { return [] }
                let query = state.query
                return [
                    Channel(id: "poll", lifetime: .ephemeral(resetKey: query, settle: .seconds(1))) { _ in
                        opens.mutate { $0.append(query) }
                        return .cancelOnly { cancels.mutate { $0 += 1 } }
                    }
                ]
            }
        }
        let store = Store(initial: Search(), behavior: .combine(reducer, supervisor), environment: (), clock: { _ in clock })

        store.dispatch(.setQuery("h")) // appears → settling, not yet open
        store.dispatch(.setQuery("he")) // key changes → settle restarts
        store.dispatch(.setQuery("hel"))
        for _ in 0..<20 {
            await Task.yield()
        }
        #expect(opens.value.isEmpty) // creation deferred while the query keeps changing

        await clock.waitForSleepers()
        await clock.advance(by: .seconds(1)) // query quiet for `settle` → opens once, with the settled value
        await poll { opens.value == ["hel"] }
        #expect(opens.value == ["hel"])
        #expect(cancels.value == 0)

        store.dispatch(.setQuery("hell")) // a further change kills the live instance NOW…
        await poll { cancels.value == 1 }
        #expect(opens.value == ["hel"]) // …and defers the reopen
        await clock.waitForSleepers()
        await clock.advance(by: .seconds(1))
        await poll { opens.value == ["hel", "hell"] }
        #expect(opens.value == ["hel", "hell"]) // reopened with the new settled key
    }

    // MARK: - A `.nothing` channel is a PassthroughSubject: its FIRST broadcast goes straight through

    private struct Socket: Sendable, Equatable { var connected = false; var received: [Int] = [] }
    private enum SocketAction: Sendable, Equatable { case connect, send(Int), got(Int) }

    @Test func passthroughChannelDeliversFirstBroadcastThenThrottles() async {
        let clock = TestClock()
        let behavior = Behavior<SocketAction, Socket, Void>
            .reduce { action, state in
                switch action {
                case .connect: state.connected = true
                case let .got(v): state.received.append(v)
                case .send: break
                }
            }
            .produce { action, _ in
                guard case let .send(v) = action else { return Reader { _ in .empty } }
                return Reader { _ in .broadcast(v, channel: "socket") }
            }
            .supervise { state in
                Supervision { _ in
                    guard state.connected else { return [] }
                    return [
                        Channel(id: "socket", delivery: .throttle(.seconds(1))) { dispatch in
                            ChannelHandler(receive: { dispatch(.got($0)) }, cancel: {})
                        }
                    ]
                }
            }
        let store = Store(initial: Socket(), behavior: behavior, environment: (), clock: { _ in clock })

        store.dispatch(.connect) // opens the channel — delivers nothing (no initial value)
        store.dispatch(.send(1)) // first broadcast → straight through; the open set no window
        await poll { store.state.received == [1] }
        #expect(store.state.received == [1])

        store.dispatch(.send(2)) // inside the window → throttled
        for _ in 0..<20 {
            await Task.yield()
        }
        #expect(store.state.received == [1])

        await clock.advance(by: .seconds(1))
        store.dispatch(.send(3)) // window elapsed → delivered into the same live channel
        await poll { store.state.received == [1, 3] }
        #expect(store.state.received == [1, 3])
    }
}
