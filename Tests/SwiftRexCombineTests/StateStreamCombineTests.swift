// SPDX-License-Identifier: Apache-2.0

#if canImport(Combine)
    import Combine
    import Foundation
    import SwiftRex
    import SwiftRexCombine
    import Testing

    @Suite("StateStream — Combine Publisher")
    @MainActor
    struct StateStreamCombineTests {
        private func counterStore(initial: Int = 0) -> Store<Int, Int, Void> {
            Store(initial: initial, reducer: Reducer.reduce { action, state in state += action })
        }

        @Test func deliversTheCurrentValueSynchronouslyOnMain() {
            let store = counterStore(initial: 3)
            var received: [Int] = []
            let cancellable = store.stateStream.sink { received.append($0) }
            #expect(received == [3])
            store.dispatch(1)
            #expect(received == [3, 4])
            cancellable.cancel()
        }

        @Test func cancellingStopsDeliverySynchronously() {
            let store = counterStore()
            var received: [Int] = []
            let cancellable = store.stateStream.sink { received.append($0) }
            cancellable.cancel()
            store.dispatch(1)
            #expect(received == [0])
        }

        @Test func streamOperatorsKeepItAPublisher() {
            let store = counterStore()
            var received: [String] = []
            let cancellable = store.stateStream
                .map { $0 / 2 }
                .removeDuplicates()
                .map { "\($0)" }
                .sink { received.append($0) }
            store.dispatch(1)
            store.dispatch(1)
            #expect(received == ["0", "1"])
            cancellable.cancel()
        }

        @Test func withoutDemandOnlyTheLatestValueIsKept() {
            let store = counterStore()
            let subscriber = ManualSubscriber()
            store.stateStream.subscribe(subscriber)
            subscriber.request(1)
            #expect(subscriber.received == [0])
            store.dispatch(1)
            store.dispatch(1)
            store.dispatch(1)
            #expect(subscriber.received == [0])
            subscriber.request(5)
            #expect(subscriber.received == [0, 3])     // 1 and 2 were superseded
            store.dispatch(1)
            #expect(subscriber.received == [0, 3, 4])
            subscriber.cancel()
        }

        @Test func subscribingOffMainDeliversOnMain() async {
            let store = counterStore(initial: 8)
            let stream = store.stateStream
            let delivery = await withCheckedContinuation { (continuation: CheckedContinuation<(Int, Bool), Never>) in
                DispatchQueue.global().async {
                    var cancellable: AnyCancellable?
                    cancellable = stream.first().sink { value in
                        continuation.resume(returning: (value, Thread.isMainThread))
                        _ = cancellable
                    }
                }
            }
            #expect(delivery.0 == 8)
            #expect(delivery.1)
        }
    }

    /// A subscriber that asks for values only when told to.
    @MainActor
    private final class ManualSubscriber: Subscriber, @unchecked Sendable {
        typealias Input = Int
        typealias Failure = Never

        private(set) var received: [Int] = []
        private var subscription: Subscription?

        nonisolated func receive(subscription: Subscription) {
            nonisolated(unsafe) let subscription = subscription   // the stream delivers on main; tests subscribe on main
            MainActor.assumeIsolated { self.subscription = subscription }
        }

        nonisolated func receive(_ input: Int) -> Subscribers.Demand {
            MainActor.assumeIsolated { received.append(input) }
            return .none
        }

        nonisolated func receive(completion: Subscribers.Completion<Never>) {}

        func request(_ demand: Int) { subscription?.request(.max(demand)) }
        func cancel() { subscription?.cancel() }
    }
#endif
