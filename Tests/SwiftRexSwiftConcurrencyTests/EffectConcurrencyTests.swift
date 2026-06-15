import SwiftRex
@testable import SwiftRexSwiftConcurrency
import Testing

@Suite
struct EffectFutureTests {
    @Test func futureDispatchesAction() async {
        let received = LockProtected([Int]())
        subscribeAll(Effect<Int>.future { completer in completer.complete(99) }) { dispatched in
            received.mutate { $0.append(dispatched.action) }
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(received.value == [99])
    }

    @Test func futureCapturesCallSite() async {
        let line: UInt = #line
        let received = LockProtected([DispatchedAction<Int>]())
        subscribeAll(Effect<Int>.future({ completer in completer.complete(1) }, line: line)) { dispatched in
            received.mutate { $0.append(dispatched) }
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(received.value[0].dispatcher.line == line)
    }

    @Test func futureCallsComplete() async {
        let completed = LockProtected(false)
        subscribeAll(
            Effect<Int>.future { completer in completer.complete(1) },
            send: { _ in },
            onComplete: { completed.set(true) }
        )
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(completed.value)
    }

    @Test func futureTokenCancellationSkipsDispatchAndComplete() async {
        let received = LockProtected([Int]())
        let completed = LockProtected(false)
        let token = Effect<Int>.future { _ in
            // completer dropped without completing
        }.components[0].subscribe(
            { dispatched in received.mutate { $0.append(dispatched.action) } },
            { completed.set(true) }
        )
        token.cancel()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(received.value.isEmpty)
        #expect(!completed.value)
    }
}

@Suite
struct EffectTaskTests {
    @Test func taskDispatchesAsyncAction() async {
        let received = LockProtected([Int]())
        subscribeAll(Effect<Int>.task { 7 }) { dispatched in
            received.mutate { $0.append(dispatched.action) }
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(received.value == [7])
    }

    @Test func taskCallsComplete() async {
        let completed = LockProtected(false)
        subscribeAll(Effect<Int>.task { 42 }, send: { _ in }, onComplete: { completed.set(true) })
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(completed.value)
    }

    @Test func taskNilProducesNoAction() async {
        let received = LockProtected([Int]())
        let token = Effect<Int>.task { nil }.components[0].subscribe(
            { dispatched in received.mutate { $0.append(dispatched.action) } }, { }
        )
        try? await Task.sleep(nanoseconds: 100_000_000)
        token.cancel()
        #expect(received.value.isEmpty)
    }

    @Test func taskCancelledDoesNotCallComplete() async {
        let completed = LockProtected(false)
        let token = Effect<Int>.task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            return 1
        }.components[0].subscribe({ _ in }, { completed.set(true) })
        token.cancel()
        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(!completed.value)
    }
}

@Suite
struct EffectFireAndForgetTests {
    @Test func fireAndForgetRunsWork() async {
        let ran = LockProtected(false)
        subscribeAll(Effect<Int>.fireAndForget { ran.set(true) }, send: { _ in })
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(ran.value)
    }

    @Test func fireAndForgetCallsComplete() async {
        let completed = LockProtected(false)
        subscribeAll(Effect<Int>.fireAndForget { }, send: { _ in }, onComplete: { completed.set(true) })
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(completed.value)
    }

    @Test func fireAndForgetDispatchesNoActions() async {
        let received = LockProtected([Int]())
        subscribeAll(Effect<Int>.fireAndForget { }, send: { dispatched in received.mutate { $0.append(dispatched.action) } })
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(received.value.isEmpty)
    }
}

// MARK: - Auto-cancel on release (SubscriptionToken is RAII, like AnyCancellable)

@Suite
struct EffectAutoCancelTests {
    /// Releasing the last reference to a `SubscriptionToken` cancels its effect — the running
    /// task is cancelled and `complete` is never called.
    @Test func droppingTokenCancelsTask() async {
        let completed = LockProtected(false)
        do {
            let token = Effect<Int>.task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                return 1
            }.components[0].subscribe({ _ in }, { completed.set(true) })
            _ = token
        } // token released here → deinit → cancel
        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(!completed.value)
    }

    /// Deallocating the Store releases its effect registry, whose tokens cancel the in-flight
    /// effects — the work never runs to completion.
    @Test func deallocatingStoreCancelsInFlightEffect() async {
        let ranToEnd = LockProtected(false)
        do {
            let store = await MainActor.run {
                let store = Store(
                    initial: 0,
                    behavior: Behavior<Int, Int, Void>.handle { _, _ in
                        .produce { _ in
                            Effect<Int>.task {
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                if !Task.isCancelled { ranToEnd.set(true) }
                                return nil
                            }
                        }
                    },
                    environment: ()
                )
                store.dispatch(0) // schedules the effect synchronously before returning
                return store
            }
            _ = store
        } // store released → effects dictionary released → tokens cancel
        try? await Task.sleep(nanoseconds: 250_000_000)
        #expect(!ranToEnd.value)
    }

    /// Scheduling a `.replacing` effect under a key in use cancels the effect it displaces —
    /// the `Set<AnyCancellable>`-style behavior the registry provides via token release.
    @Test func replacingCancelsDisplacedEffect() async {
        let completedActions = LockProtected<[Int]>([])
        let store = await MainActor.run {
            Store(
                initial: 0,
                behavior: Behavior<Int, Int, Void>.handle { action, _ in
                    .produce { _ in
                        Effect<Int>.task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            if !Task.isCancelled { completedActions.mutate { $0.append(action) } }
                            return nil
                        }.scheduling(.replacing(id: "job"))
                    }
                },
                environment: ()
            )
        }
        await MainActor.run { _ = store.dispatch(1) }     // starts job for action 1
        try? await Task.sleep(nanoseconds: 50_000_000)
        await MainActor.run { _ = store.dispatch(2) }     // replaces under "job" → cancels job 1
        try? await Task.sleep(nanoseconds: 400_000_000)
        #expect(completedActions.value == [2])   // job 1 cancelled, only job 2 completed
        _ = store
    }
}
