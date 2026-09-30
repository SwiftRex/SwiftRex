// SPDX-License-Identifier: Apache-2.0

#if canImport(Combine)
    import Combine
    import SwiftRex
    @testable import SwiftRexCombine
    import Testing

    // MARK: - Helpers

    private func collect<A: Sendable>(
        _ effect: Effect<A>,
        timeout: Duration = .milliseconds(500)
    ) async -> [A] {
        await withCheckedContinuation { continuation in
            let received = LockProtected([A]())
            let tokens = LockProtected([SubscriptionToken]())
            let t = subscribeAll(effect, send: { d in received.mutate { $0.append(d.action) } }, onComplete: {
                continuation.resume(returning: received.value)
            })
            tokens.mutate { $0 = t }
        }
    }

    // MARK: - Publisher<Action, Never>.asEffect

    @Suite("Effect+Combine: Publisher<Action, Never>")
    struct PublisherActionEffectTests {
        @Test func dispatchesAllValues() async {
            let effect = [1, 2, 3].publisher.asEffect()
            let received = await collect(effect)
            #expect(received == [1, 2, 3])
        }

        @Test func callsCompleteOnFinished() async {
            let completed = LockProtected(false)
            _ = subscribeAll(
                [1].publisher.asEffect(),
                send: { _ in },
                onComplete: { completed.set(true) }
            )
            try? await Task.sleep(for: .milliseconds(50))
            #expect(completed.value)
        }

        @Test func capturesCallSiteAsDispatcher() async {
            let line: UInt = #line; let effect = [42].publisher.asEffect(line: line)
            let received = LockProtected([DispatchedAction<Int>]())
            _ = subscribeAll(effect, send: { d in received.mutate { $0.append(d) } })
            try? await Task.sleep(for: .milliseconds(50))
            #expect(received.value.first?.dispatcher.line == line)
        }

        @Test func tokenCancellationStopsDelivery() async {
            let subject = PassthroughSubject<Int, Never>()
            let received = LockProtected([Int]())
            let token = subscribeAll(subject.asEffect(), send: { d in received.mutate { $0.append(d.action) } })[0]
            subject.send(1)
            token.cancel()
            subject.send(2)
            try? await Task.sleep(for: .milliseconds(50))
            #expect(received.value == [1])
        }
    }

    // MARK: - Publisher<DispatchedAction<A>, Never>.asEffect (forwarding)

    @Suite("Effect+Combine: Publisher<DispatchedAction<A>, Never> forwarding")
    struct PublisherForwardingEffectTests {
        @Test func preservesExistingDispatcher() async {
            let source = ActionSource(file: "original.swift", function: "fn()", line: 99)
            let dispatched = DispatchedAction(42, dispatcher: source)
            let effect: Effect<Int> = [dispatched].publisher.asEffect()
            let received = LockProtected([DispatchedAction<Int>]())
            _ = subscribeAll(effect, send: { d in received.mutate { $0.append(d) } })
            try? await Task.sleep(for: .milliseconds(50))
            #expect(received.value.first?.dispatcher.file == "original.swift")
            #expect(received.value.first?.action == 42)
        }
    }

    // MARK: - Publisher<Output, Never>.asEffect(_ transform:)

    @Suite("Effect+Combine: Publisher<Output, Never> with transform")
    struct PublisherTransformEffectTests {
        @Test func appliesTransform() async {
            let effect = [5].publisher.asEffect { "val:\($0)" }
            let received = await collect(effect)
            #expect(received == ["val:5"])
        }
    }

    // MARK: - Publisher<Output, Error>.asEffect(_ transform:) — Result

    @Suite("Effect+Combine: Publisher<Output, Error> with Result transform")
    struct PublisherResultEffectTests {
        @Test func wrapsSuccessInResult() async {
            struct TestError: Error {}
            let effect = Just(10)
                .setFailureType(to: TestError.self)
                .asEffect { (r: Result<Int, TestError>) in (try? r.get()).map { $0 * 2 } ?? -1 }
            let received = await collect(effect)
            #expect(received == [20])
        }

        @Test func wrapsFailureInResult() async {
            struct E: Error {}
            let effect = Fail<Int, E>(error: E())
                .asEffect { (r: Result<Int, E>) in
                    switch r {
                    case .failure: -1
                    case .success: 0
                    }
                }
            let received = await collect(effect)
            #expect(received == [-1])
        }
    }

    // MARK: - Effect.fireAndForget (Combine)

    @Suite("Effect+Combine: fireAndForget")
    struct CombineFireAndForgetTests {
        @Test func dispatchesNoActions() async {
            let received = LockProtected([Int]())
            _ = subscribeAll(
                Effect<Int>.fireAndForget([1, 2].publisher),
                send: { d in received.mutate { $0.append(d.action) } }
            )
            try? await Task.sleep(for: .milliseconds(50))
            #expect(received.value.isEmpty)
        }

        @Test func callsCompleteWhenPublisherFinishes() async {
            let completed = LockProtected(false)
            _ = subscribeAll(
                Effect<Int>.fireAndForget([1].publisher),
                send: { _ in },
                onComplete: { completed.set(true) }
            )
            try? await Task.sleep(for: .milliseconds(50))
            #expect(completed.value)
        }
    }

    // MARK: - StateStream is a Combine Publisher

    @Suite("StateStream+Combine: Publisher")
    @MainActor
    struct StateStreamPublisherTests {
        @Test func isLazyThenDeliversTheCurrentValueFirst() {
            let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { a, s in s += a })
            var received = [Int]()
            let pub = store.stateStream
            store.dispatch(10)
            #expect(received.isEmpty) // nothing subscribed yet
            let token = pub.sink { received.append($0) }
            #expect(received == [10]) // current value, synchronously on subscription from the main actor
            store.dispatch(5)
            #expect(received == [10, 15])
            token.cancel()
        }

        @Test func deliversStateAfterEachDispatch() {
            let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { a, s in s += a })
            var received = [Int]()
            let token = store.stateStream.sink { received.append($0) }
            store.dispatch(3)
            store.dispatch(4)
            #expect(received == [0, 3, 7])
            token.cancel()
        }

        @Test func cancellingStopsDelivery() {
            let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { a, s in s += a })
            var received = [Int]()
            var token: AnyCancellable? = store.stateStream.sink { received.append($0) }
            store.dispatch(1)
            token = nil
            store.dispatch(2)
            #expect(received == [0, 1])
            _ = token
        }

        @Test func honoursDemandKeepingOnlyTheLatestValue() {
            let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { a, s in s += a })
            var received = [Int]()
            var subscription: (any Subscription)?
            let subscriber = AnySubscriber<Int, Never>(
                receiveSubscription: { subscription = $0; $0.request(.max(1)) },
                receiveValue: { received.append($0); return .none },
                receiveCompletion: { _ in }
            )
            store.stateStream.subscribe(subscriber)
            #expect(received == [0])
            store.dispatch(1)
            store.dispatch(2)
            #expect(received == [0]) // no demand: nothing delivered, only the latest kept
            subscription?.request(.max(1))
            #expect(received == [0, 3]) // the latest state, not the backlog
            subscription?.cancel()
        }

        @Test func ownMapKeepsItAStateStream() {
            let store = Store(initial: 1, reducer: Reducer<Int, Int>.reduce { a, s in s += a })
            let doubled: StateStream<Int> = store.stateStream.map { $0 * 2 } // StateStream's map, not Combine's
            var received = [Int]()
            let token = doubled.sink { received.append($0) }
            #expect(received == [2])
            token.cancel()
        }
    }
#endif
