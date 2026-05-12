import XCTest
import SwiftRex
@testable import SwiftRexConcurrency

final class EffectFutureTests: XCTestCase {
    func testFutureDispatchesAction() async {
        let exp = expectation(description: "future")
        let received = LockProtected([Int]())
        _ = Effect<Int>.future { completer in
            completer.complete(99)
        }.components[0].subscribe { d in
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
        _ = Effect<Int>.future({ completer in
            completer.complete(1)
        }, line: line).components[0].subscribe { d in
            received.mutate { $0.append(d) }
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(received.value[0].dispatcher.line, line)
    }

    func testFutureTokenCancellationSkipsDispatch() async {
        let received = LockProtected([Int]())
        let token = Effect<Int>.future { completer in
            // completer is never completed — deinit will cancel
            _ = completer  // force completer to be captured but not completed
        }.components[0].subscribe { d in received.mutate { $0.append(d.action) } }
        token.cancel()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(received.value.isEmpty)
    }
}

final class EffectTaskTests: XCTestCase {
    func testTaskDispatchesAsyncAction() async {
        let exp = expectation(description: "task")
        let received = LockProtected([Int]())
        _ = Effect<Int>.task { 7 }.components[0].subscribe { d in
            received.mutate { $0.append(d.action) }
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(received.value, [7])
    }

    func testTaskNilProducesNoAction() async {
        let received = LockProtected([Int]())
        let token = Effect<Int>.task { nil }.components[0].subscribe { d in
            received.mutate { $0.append(d.action) }
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        token.cancel()
        XCTAssertTrue(received.value.isEmpty)
    }

    func testTaskCapturesCallSite() async {
        let exp = expectation(description: "task callsite")
        let line: UInt = #line
        let received = LockProtected([DispatchedAction<Int>]())
        _ = Effect<Int>.task({ 42 }, line: line).components[0].subscribe { d in
            received.mutate { $0.append(d) }
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(received.value[0].dispatcher.line, line)
    }
}

final class EffectFireAndForgetTests: XCTestCase {
    func testFireAndForgetRunsWork() async {
        let exp = expectation(description: "fireAndForget")
        _ = Effect<Int>.fireAndForget { exp.fulfill() }.components[0].subscribe { _ in }
        await fulfillment(of: [exp], timeout: 1)
    }

    func testFireAndForgetDispatchesNoActions() async {
        let received = LockProtected([Int]())
        _ = Effect<Int>.fireAndForget { }.components[0].subscribe { d in
            received.mutate { $0.append(d.action) }
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(received.value.isEmpty)
    }
}
