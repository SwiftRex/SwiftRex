import Testing
import RxSwift
import SwiftRex
@testable import SwiftRexRxSwift

// MARK: - Infallible<Action>.asEffect

@Suite("Effect+RxSwift: Infallible<Action>")
struct InfallibleActionEffectTests {
    @Test func dispatchesAllValues() {
        let received = LockProtected([Int]())
        let completed = LockProtected(false)
        _ = subscribeAll(
            Infallible.from([1, 2, 3]).asEffect(),
            send: { d in received.mutate { $0.append(d.action) } },
            onComplete: { completed.set(true) }
        )
        #expect(received.value == [1, 2, 3])
        #expect(completed.value)
    }

    @Test func capturesCallSiteAsDispatcher() {
        let line: UInt = #line; let effect: Effect<Int> = Infallible.just(42).asEffect(line: line)
        let received = LockProtected([DispatchedAction<Int>]())
        _ = subscribeAll(effect, send: { d in received.mutate { $0.append(d) } })
        #expect(received.value.first?.dispatcher.line == line)
    }

    @Test func tokenCancellationStopsDelivery() {
        let subject = PublishSubject<Int>()
        let received = LockProtected([Int]())
        let token = subscribeAll(
            subject.asInfallible(onErrorJustReturn: -1).asEffect(),
            send: { d in received.mutate { $0.append(d.action) } }
        )[0]
        subject.onNext(1)
        token.cancel()
        subject.onNext(2)
        #expect(received.value == [1])
    }
}

// MARK: - Infallible<DispatchedAction<A>>.asEffect (forwarding)

@Suite("Effect+RxSwift: Infallible<DispatchedAction<A>> forwarding")
struct InfallibleForwardingEffectTests {
    @Test func preservesExistingDispatcher() {
        let source = ActionSource(file: "orig.swift", function: "f()", line: 77)
        let dispatched = DispatchedAction(10, dispatcher: source)
        let effect: Effect<Int> = Infallible.just(dispatched).asEffect()
        let received = LockProtected([DispatchedAction<Int>]())
        _ = subscribeAll(effect, send: { d in received.mutate { $0.append(d) } })
        #expect(received.value.first?.dispatcher.file == "orig.swift")
        #expect(received.value.first?.action == 10)
    }
}

// MARK: - Infallible<Output>.asEffect(_ transform:)

@Suite("Effect+RxSwift: Infallible<Output> with transform")
struct InfallibleTransformEffectTests {
    @Test func appliesTransform() {
        let received = LockProtected([String]())
        _ = subscribeAll(
            Infallible.just(5).asEffect { "n:\($0)" },
            send: { d in received.mutate { $0.append(d.action) } }
        )
        #expect(received.value == ["n:5"])
    }
}

// MARK: - Observable<Action>.asEffect — errors discarded

@Suite("Effect+RxSwift: Observable<Action> (errors discarded)")
struct ObservableActionEffectTests {
    @Test func dispatchesValuesAndCompletesOnFinished() {
        let received = LockProtected([Int]())
        let completed = LockProtected(false)
        _ = subscribeAll(
            Observable.from([10, 20]).asEffect(),
            send: { d in received.mutate { $0.append(d.action) } },
            onComplete: { completed.set(true) }
        )
        #expect(received.value == [10, 20])
        #expect(completed.value)
    }

    @Test func errorSilentlyCompletesEffect() {
        struct E: Error {}
        let completed = LockProtected(false)
        let received = LockProtected([Int]())
        _ = subscribeAll(
            Observable<Int>.error(E()).asEffect(),
            send: { d in received.mutate { $0.append(d.action) } },
            onComplete: { completed.set(true) }
        )
        #expect(received.value.isEmpty)
        #expect(completed.value)
    }
}

// MARK: - Observable<Output>.asEffect(_ transform:) — Result variant

@Suite("Effect+RxSwift: Observable<Output> with Result transform")
struct ObservableResultEffectTests {
    @Test func wrapsSuccessInResult() {
        let received = LockProtected([Int]())
        _ = subscribeAll(
            Observable.just(7).asEffect { (r: Result<Int, Error>) in (try? r.get()) ?? -1 },
            send: { d in received.mutate { $0.append(d.action) } }
        )
        #expect(received.value == [7])
    }

    @Test func wrapsFailureInResult() {
        struct E: Error {}
        let received = LockProtected([Int]())
        _ = subscribeAll(
            Observable<Int>.error(E()).asEffect { (r: Result<Int, Error>) in
                switch r { case .failure: return -1; case .success: return 0 }
            },
            send: { d in received.mutate { $0.append(d.action) } }
        )
        #expect(received.value == [-1])
    }
}

// MARK: - Effect.fireAndForget (Observable)

@Suite("Effect+RxSwift: fireAndForget")
struct RxSwiftFireAndForgetTests {
    @Test func dispatchesNoActions() {
        let received = LockProtected([Int]())
        _ = subscribeAll(
            Effect<Int>.fireAndForget(Observable.from([1, 2])),
            send: { d in received.mutate { $0.append(d.action) } }
        )
        #expect(received.value.isEmpty)
    }

    @Test func callsCompleteOnFinish() {
        let completed = LockProtected(false)
        _ = subscribeAll(
            Effect<Int>.fireAndForget(Observable<Int>.empty()),
            send: { _ in },
            onComplete: { completed.set(true) }
        )
        #expect(completed.value)
    }
}

// MARK: - StoreType+RxSwift: .observable

@Suite("StoreType+RxSwift: observable")
@MainActor
struct StoreObservableTests {
    @Test func observableIsLazyDoesNotEmitBeforeSubscribe() async {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { a, s in s += a })
        var received = [Int]()
        let obs = store.observable
        store.dispatch(10)
        #expect(received.isEmpty)
        let bag = DisposeBag()
        obs.subscribe(onNext: { received.append($0) }).disposed(by: bag)
        await Task.yield() // let the observe token set up
        store.dispatch(5)  // state: 10+5=15
        #expect(received == [15])
    }

    @Test func observableDeliversStateAfterEachDispatch() async {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { a, s in s += a })
        var received = [Int]()
        let bag = DisposeBag()
        store.observable.subscribe(onNext: { received.append($0) }).disposed(by: bag)
        await Task.yield()
        store.dispatch(3)  // state: 3
        store.dispatch(4)  // state: 7
        #expect(received == [3, 7])
    }
}
