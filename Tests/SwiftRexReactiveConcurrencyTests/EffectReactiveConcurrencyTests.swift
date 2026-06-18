#if ReactiveConcurrency
import ReactiveConcurrency
import SwiftRex
@testable import SwiftRexReactiveConcurrency
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

@Suite("Effect+ReactiveConcurrency: Publisher<Action, Never>")
struct PublisherActionEffectTests {
    @Test func dispatchesAllValues() async {
        let effect = Publisher<Int, Never>.sequence([1, 2, 3]).asEffect()
        let received = await collect(effect)
        #expect(received == [1, 2, 3])
    }

    @Test func callsCompleteOnFinished() async {
        let completed = LockProtected(false)
        _ = subscribeAll(
            Publisher<Int, Never>.just(1).asEffect(),
            send: { _ in },
            onComplete: { completed.set(true) }
        )
        try? await Task.sleep(for: .milliseconds(100))
        #expect(completed.value)
    }

    @Test func capturesCallSiteAsDispatcher() async {
        let line: UInt = #line; let effect = Publisher<Int, Never>.just(42).asEffect(line: line)
        let received = LockProtected([DispatchedAction<Int>]())
        _ = subscribeAll(effect, send: { d in received.mutate { $0.append(d) } })
        try? await Task.sleep(for: .milliseconds(100))
        #expect(received.value.first?.dispatcher.line == line)
    }

    @Test func tokenCancellationStopsDelivery() async {
        let subject = PassthroughSubject<Int, Never>()
        let received = LockProtected([Int]())
        let token = subscribeAll(
            subject.eraseToPublisher().asEffect(),
            send: { d in received.mutate { $0.append(d.action) } }
        )[0]
        try? await Task.sleep(for: .milliseconds(50))
        subject.send(1)
        try? await Task.sleep(for: .milliseconds(50))
        token.cancel()
        subject.send(2)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(received.value == [1])
    }
}

// MARK: - Publisher<DispatchedAction<A>, Never>.asEffect (forwarding)

@Suite("Effect+ReactiveConcurrency: Publisher<DispatchedAction<A>, Never> forwarding")
struct PublisherForwardingEffectTests {
    @Test func preservesExistingDispatcher() async {
        let source = ActionSource(file: "original.swift", function: "fn()", line: 99)
        let dispatched = DispatchedAction(42, dispatcher: source)
        let effect: Effect<Int> = Publisher<DispatchedAction<Int>, Never>.sequence([dispatched]).asEffect()
        let received = LockProtected([DispatchedAction<Int>]())
        _ = subscribeAll(effect, send: { d in received.mutate { $0.append(d) } })
        try? await Task.sleep(for: .milliseconds(100))
        #expect(received.value.first?.dispatcher.file == "original.swift")
        #expect(received.value.first?.action == 42)
    }
}

// MARK: - Publisher<Output, Never>.asEffect(_ transform:)

@Suite("Effect+ReactiveConcurrency: Publisher<Output, Never> with transform")
struct PublisherTransformEffectTests {
    @Test func appliesTransform() async {
        let effect = Publisher<Int, Never>.sequence([5]).asEffect { "val:\($0)" }
        let received = await collect(effect)
        #expect(received == ["val:5"])
    }
}

// MARK: - Publisher<Output, Error>.asEffect(_ transform:) — Result

@Suite("Effect+ReactiveConcurrency: Publisher<Output, Error> with Result transform")
struct PublisherResultEffectTests {
    @Test func wrapsSuccessInResult() async {
        struct TestError: Error {}
        let effect = Publisher<Int, TestError>.just(10)
            .asEffect { (r: Result<Int, TestError>) in (try? r.get()).map { $0 * 2 } ?? -1 }
        let received = await collect(effect)
        #expect(received == [20])
    }

    @Test func wrapsFailureInResult() async {
        struct E: Error {}
        let effect = Publisher<Int, E>.fail(E())
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

// MARK: - Effect.fireAndForget (ReactiveConcurrency)

@Suite("Effect+ReactiveConcurrency: fireAndForget")
struct ReactiveConcurrencyFireAndForgetTests {
    @Test func dispatchesNoActions() async {
        let received = LockProtected([Int]())
        _ = subscribeAll(
            Effect<Int>.fireAndForget(Publisher<Int, Never>.sequence([1, 2])),
            send: { d in received.mutate { $0.append(d.action) } }
        )
        try? await Task.sleep(for: .milliseconds(100))
        #expect(received.value.isEmpty)
    }

    @Test func callsCompleteWhenPublisherFinishes() async {
        let completed = LockProtected(false)
        _ = subscribeAll(
            Effect<Int>.fireAndForget(Publisher<Int, Never>.just(1)),
            send: { _ in },
            onComplete: { completed.set(true) }
        )
        try? await Task.sleep(for: .milliseconds(100))
        #expect(completed.value)
    }
}

// MARK: - StoreType+ReactiveConcurrency: .publisher
//
// RC's `store.publisher` is a cold publisher consumed by a Task, so delivery is asynchronous
// (unlike Combine's synchronous observer). Tests await propagation and read through a lock.

@Suite("StoreType+ReactiveConcurrency: publisher")
@MainActor
struct StorePublisherTests {
    @Test func publisherIsLazyDoesNotSubscribeUntilStarted() async {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { a, s in s += a })
        let received = LockProtected([Int]())
        let pub = store.publisher
        store.dispatch(10)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(received.value.isEmpty)
        let token = pub.sink { value in received.mutate { $0.append(value) } }
        try? await Task.sleep(for: .milliseconds(50)) // let the observer register on @MainActor
        store.dispatch(5)  // state: 10+5=15
        try? await Task.sleep(for: .milliseconds(50))
        #expect(received.value == [15])
        token.cancel()
    }

    @Test func publisherDeliversStateAfterEachDispatch() async {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { a, s in s += a })
        let received = LockProtected([Int]())
        let token = store.publisher.sink { value in received.mutate { $0.append(value) } }
        try? await Task.sleep(for: .milliseconds(50))
        store.dispatch(3)  // state: 3
        store.dispatch(4)  // state: 7
        try? await Task.sleep(for: .milliseconds(50))
        #expect(received.value == [3, 7])
        token.cancel()
    }

    @Test func cancellingSubscriptionStopsDelivery() async {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { a, s in s += a })
        let received = LockProtected([Int]())
        var token: AnyCancellable? = store.publisher.sink { value in received.mutate { $0.append(value) } }
        try? await Task.sleep(for: .milliseconds(50))
        store.dispatch(1)  // state: 1
        try? await Task.sleep(for: .milliseconds(50))
        token = nil
        store.dispatch(2)  // state: 3, not subscribed
        try? await Task.sleep(for: .milliseconds(50))
        #expect(received.value == [1])
        _ = token
    }
}
#endif
