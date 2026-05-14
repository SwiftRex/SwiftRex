import ReactiveSwift
import SwiftRex
@testable import SwiftRexReactiveSwift
import Testing

// MARK: - SignalProducer<Action, Never>.asEffect

@Suite("Effect+ReactiveSwift: SignalProducer<Action, Never>")
struct SignalProducerActionEffectTests {
    @Test func dispatchesAllValues() {
        let received = LockProtected([Int]())
        let completed = LockProtected(false)
        _ = subscribeAll(
            SignalProducer([1, 2, 3]).asEffect(),
            send: { d in received.mutate { $0.append(d.action) } },
            onComplete: { completed.set(true) }
        )
        #expect(received.value == [1, 2, 3])
        #expect(completed.value)
    }

    @Test func capturesCallSiteAsDispatcher() {
        let line: UInt = #line; let effect: Effect<Int> = SignalProducer(value: 42).asEffect(line: line)
        let received = LockProtected([DispatchedAction<Int>]())
        _ = subscribeAll(effect, send: { d in received.mutate { $0.append(d) } })
        #expect(received.value.first?.dispatcher.line == line)
    }

    @Test func tokenCancellationStopsDelivery() {
        let (signal, observer) = Signal<Int, Never>.pipe()
        let received = LockProtected([Int]())
        let token = subscribeAll(
            SignalProducer(signal).asEffect(),
            send: { d in received.mutate { $0.append(d.action) } }
        )[0]
        observer.send(value: 1)
        token.cancel()
        observer.send(value: 2)
        #expect(received.value == [1])
    }
}

// MARK: - SignalProducer<DispatchedAction<A>, Never>.asEffect (forwarding)

@Suite("Effect+ReactiveSwift: SignalProducer<DispatchedAction<A>, Never> forwarding")
struct SignalProducerForwardingEffectTests {
    @Test func preservesExistingDispatcher() {
        let source = ActionSource(file: "orig.swift", function: "f()", line: 77)
        let dispatched = DispatchedAction(10, dispatcher: source)
        let effect: Effect<Int> = SignalProducer<DispatchedAction<Int>, Never>(value: dispatched).asEffect()
        let received = LockProtected([DispatchedAction<Int>]())
        _ = subscribeAll(effect, send: { d in received.mutate { $0.append(d) } })
        #expect(received.value.first?.dispatcher.file == "orig.swift")
        #expect(received.value.first?.action == 10)
    }
}

// MARK: - SignalProducer<Output, Never>.asEffect(_ transform:)

@Suite("Effect+ReactiveSwift: SignalProducer<Output, Never> with transform")
struct SignalProducerTransformEffectTests {
    @Test func appliesTransform() {
        let received = LockProtected([String]())
        _ = subscribeAll(
            SignalProducer(value: 5).asEffect { "n:\($0)" },
            send: { d in received.mutate { $0.append(d.action) } }
        )
        #expect(received.value == ["n:5"])
    }
}

// MARK: - SignalProducer<Output, Error>.asEffect — Result variant

@Suite("Effect+ReactiveSwift: SignalProducer<Output, Error> with Result transform")
struct SignalProducerResultEffectTests {
    @Test func wrapsSuccessInResult() {
        struct E: Error {}
        let received = LockProtected([Int]())
        _ = subscribeAll(
            SignalProducer<Int, E>(value: 7)
                .asEffect { (r: Result<Int, E>) in (try? r.get()) ?? -1 },
            send: { d in received.mutate { $0.append(d.action) } }
        )
        #expect(received.value == [7])
    }

    @Test func wrapsFailureInResult() {
        struct E: Error {}
        let received = LockProtected([Int]())
        _ = subscribeAll(
            SignalProducer<Int, E>(error: E())
                .asEffect { (r: Result<Int, E>) in
                    switch r {
                    case .failure: return -1
                    case .success: return 0
                    }
                },
            send: { d in received.mutate { $0.append(d.action) } }
        )
        #expect(received.value == [-1])
    }
}

// MARK: - Signal (hot) bridges — delegate to SignalProducer

@Suite("Effect+ReactiveSwift: Signal (hot) bridges")
struct SignalBridgeTests {
    @Test func hotSignalDispatchesValues() {
        let (signal, observer) = Signal<Int, Never>.pipe()
        let received = LockProtected([Int]())
        let token = subscribeAll(
            signal.asEffect(),
            send: { d in received.mutate { $0.append(d.action) } }
        )[0]
        observer.send(value: 5)
        observer.send(value: 6)
        token.cancel()
        #expect(received.value == [5, 6])
    }
}

// MARK: - Effect.fireAndForget (ReactiveSwift)

@Suite("Effect+ReactiveSwift: fireAndForget")
struct ReactiveSwiftFireAndForgetTests {
    @Test func dispatchesNoActions() {
        let received = LockProtected([Int]())
        _ = subscribeAll(
            Effect<Int>.fireAndForget(SignalProducer([1, 2])),
            send: { d in received.mutate { $0.append(d.action) } }
        )
        #expect(received.value.isEmpty)
    }

    @Test func callsCompleteWhenProducerFinishes() {
        let completed = LockProtected(false)
        _ = subscribeAll(
            Effect<Int>.fireAndForget(SignalProducer<Int, Never>.empty),
            send: { _ in },
            onComplete: { completed.set(true) }
        )
        #expect(completed.value)
    }
}

// MARK: - StoreType+ReactiveSwift: .signal

@Suite("StoreType+ReactiveSwift: signal")
@MainActor
struct StoreSignalTests {
    @Test func signalIsLazyDoesNotEmitBeforeStarted() async {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { a, s in s += a })
        var received = [Int]()
        let producer = store.signal
        store.dispatch(10)
        #expect(received.isEmpty)
        let (lifetime, token) = Lifetime.make()
        producer.take(during: lifetime).startWithValues { received.append($0) }
        await Task.yield() // let the observe token set up
        store.dispatch(5)  // state: 10+5=15
        #expect(received == [15])
        token.dispose()
    }

    @Test func signalDeliversStateAfterEachDispatch() async {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { a, s in s += a })
        var received = [Int]()
        let (lifetime, token) = Lifetime.make()
        store.signal.take(during: lifetime).startWithValues { received.append($0) }
        await Task.yield()
        store.dispatch(3)  // state: 3
        store.dispatch(4)  // state: 7
        #expect(received == [3, 7])
        token.dispose()
    }
}
