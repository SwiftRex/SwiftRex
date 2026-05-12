import XCTest
import SwiftRex
@testable import SwiftRexConcurrency

final class EffectFutureTests: XCTestCase {
    func testFutureDispatchesAction() async {
        let exp = expectation(description: "future")
        let received = LockProtected([Int]())
        subscribeAll(Effect<Int>.future { completer in
            completer.complete(99)
        }) { d in
            received.mutate { $0.append(d.action) }
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(received.value, [99])
    }

    func testFutureCapturesCallSite() async {
        let exp = expectation(description: "future callsite")
        let line: UInt = #line
        let received = LockProtected([DispatchedAction<Int>]())
        subscribeAll(Effect<Int>.future({ completer in completer.complete(1) }, line: line)) { d in
            received.mutate { $0.append(d) }
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(received.value[0].dispatcher.line, line)
    }

    func testFutureCallsComplete() async {
        let exp = expectation(description: "future complete")
        subscribeAll(
            Effect<Int>.future { completer in completer.complete(1) },
            send: { _ in },
            onComplete: { exp.fulfill() }
        )
        await fulfillment(of: [exp], timeout: 1)
    }

    func testFutureTokenCancellationSkipsDispatchAndComplete() async {
        let received = LockProtected([Int]())
        let completed = LockProtected(false)
        let token = Effect<Int>.future { _ in
            // completer dropped without completing
        }.components[0].subscribe(
            { d in received.mutate { $0.append(d.action) } },
            { completed.set(true) }
        )
        token.cancel()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(received.value.isEmpty)
        XCTAssertFalse(completed.value)
    }
}

final class EffectTaskTests: XCTestCase {
    func testTaskDispatchesAsyncAction() async {
        let exp = expectation(description: "task")
        let received = LockProtected([Int]())
        subscribeAll(Effect<Int>.task { 7 }) { d in
            received.mutate { $0.append(d.action) }
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(received.value, [7])
    }

    func testTaskCallsComplete() async {
        let exp = expectation(description: "task complete")
        subscribeAll(Effect<Int>.task { 42 }, send: { _ in }, onComplete: { exp.fulfill() })
        await fulfillment(of: [exp], timeout: 1)
    }

    func testTaskNilProducesNoAction() async {
        let received = LockProtected([Int]())
        let token = Effect<Int>.task { nil }.components[0].subscribe(
            { d in received.mutate { $0.append(d.action) } }, { }
        )
        try? await Task.sleep(nanoseconds: 100_000_000)
        token.cancel()
        XCTAssertTrue(received.value.isEmpty)
    }

    func testTaskCancelledDoesNotCallComplete() async {
        let completed = LockProtected(false)
        let token = Effect<Int>.task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            return 1
        }.components[0].subscribe({ _ in }, { completed.set(true) })
        token.cancel()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(completed.value)
    }
}

final class EffectFireAndForgetTests: XCTestCase {
    func testFireAndForgetRunsWork() async {
        let exp = expectation(description: "fireAndForget")
        subscribeAll(Effect<Int>.fireAndForget { exp.fulfill() }, send: { _ in })
        await fulfillment(of: [exp], timeout: 1)
    }

    func testFireAndForgetCallsComplete() async {
        let exp = expectation(description: "fireAndForget complete")
        subscribeAll(Effect<Int>.fireAndForget { }, send: { _ in }, onComplete: { exp.fulfill() })
        await fulfillment(of: [exp], timeout: 1)
    }

    func testFireAndForgetDispatchesNoActions() async {
        let received = LockProtected([Int]())
        subscribeAll(Effect<Int>.fireAndForget { }, send: { d in received.mutate { $0.append(d.action) } })
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(received.value.isEmpty)
    }
}
