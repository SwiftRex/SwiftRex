import ReactiveSwift
import ReactiveSwiftRex
import SwiftRex
import XCTest

// swiftlint:disable type_body_length
class EffectTests: XCTestCase {
    func testInitWithCancellation() {
        let sut = Effect<Void, Int>(token: "token") { _ in SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }) }
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertEqual("token", sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testInitWithoutCancellation() {
        let sut = Effect<Void, Int> { _ in SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }) }
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testInitWithoutCancellationNoDependencies() {
        let sut = Effect<Void, Int>(SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }))
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testInitWithoutCancellationIgnoringDependencies() {
        let sut: Effect<Int, Int> = Effect<Void, Int>(
            SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) })
        ).ignoringDependencies()
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (42), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testDoNothing() {
        let sut = Effect<Void, Int>.doNothing
        XCTAssertNil(sut.token)
        XCTAssertNil(sut.run((dependencies: (), toCancel: { _ in FireAndForget { } })))
    }

    func testJust() {
        let sut = Effect<Void, Int>.just(42)
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertEqual([42], received)
        XCTAssertEqual(1, completion)
    }

    func testSequenceArray() {
        let sut = Effect<Void, Int>.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testSequenceVariadics() {
        let sut = Effect<Void, Int>.sequence(1, 1, 2, 3, 5, 8, 13, 21, 34, 55)
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testPromise() {
        let sut = Effect<Int, String>.promise(token: "token") { context, callback in
            callback(String(context.dependencies + 1))
            return AnyDisposable()
        }
        var completion = 0
        var received = [String]()
        _ = sut
            .run((dependencies: 42, toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertEqual(["43"], received)
        XCTAssertEqual(1, completion)
    }

    func testAsEffectWithCancellation() {
        let sut = SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]).asEffect(token: "token")
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertEqual("token", sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testAsEffectWithoutCancellation() {
        let sut = SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]).asEffect(dispatcher: .here())
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testFireAndForgetClosure() {
        let calledClosure = expectation(description: "should have called fire and forget closure")
        let sut = Effect<Void, Int>.fireAndForget {
            calledClosure.fulfill()
        }
        var completion = 0
        var received = [Int]()

        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()

        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([], received)
        XCTAssertEqual(1, completion)
    }

    func testFireAndForgetPublisher() {
        let calledClosure = expectation(description: "should have called fire and forget closure")
        let publisher = SignalProducer(value: "test").on(value: { value in
            XCTAssertEqual(value, "test")
            calledClosure.fulfill()
        })
        let sut = Effect<Void, Int>.fireAndForget(publisher)
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([], received)
        XCTAssertEqual(1, completion)
    }

    func testFireAndForgetPublisherCatchErrorSuccess() {
        let calledClosure = expectation(description: "should have called fire and forget closure")
        let publisher = SignalProducer<String, Error>(value: "test").on(value: { value in
            XCTAssertEqual(value, "test")
            calledClosure.fulfill()
        })
        let sut = Effect<Void, Int>.fireAndForget(
            publisher,
            catchErrors: { error in
                XCTFail(error.localizedDescription)
                return nil
            }
        )
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([], received)
        XCTAssertEqual(1, completion)
    }

    func testFireAndForgetPublisherCatchErrorFailure() {
        let calledClosure = expectation(description: "should have called fire and forget error closure")
        let someError = SomeError()
        let publisher = SignalProducer<String, Error>(error: someError).on(
            failed: { error in
                XCTAssertEqual(error as? SomeError, someError)
                calledClosure.fulfill()
            },
            completed: {
                XCTFail("Success was not expected")
            },
            value: { _ in
                XCTFail("Success was not expected")
            }
        )
        let sut = Effect<Void, Int>.fireAndForget(
            publisher,
            catchErrors: { error in
                XCTAssertEqual(error as? SomeError, someError)
                return .init(42)
            }
        )
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([42], received)
        XCTAssertEqual(1, completion)
    }

    func testMergeTwo() {
        let first = SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) })
        let second = SignalProducer(value: DispatchedAction(89))
        let sut = Effect<Void, Int>(SignalProducer.merge(first, second))
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual(1, completion)
    }

    func testMergeThree() {
        let first = SignalProducer([1, 1, 2, 3, 5, 8, 13, 21].map { DispatchedAction($0) })
        let second = SignalProducer(value: DispatchedAction(34))
        let third = SignalProducer([55, 89].map { DispatchedAction($0) })
        let sut = Effect<Void, Int>(SignalProducer.merge(first, second, third))
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual(1, completion)
    }

    func testPrepend() {
        let first = SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) })
        let second = SignalProducer(value: DispatchedAction(89))
        let sut = Effect(second.prefix(first))
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual(1, completion)
    }

    func testAppend() {
        let first = SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) })
        let second = SignalProducer(value: DispatchedAction(89))
        let sut = Effect(first.concat(second))
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual(1, completion)
    }

    func testFMap() {
        let numbers = Effect<Void, Int>.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        let sut = numbers.map(String.init)
        var completion = 0
        var received = [String]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .on(
                completed: { completion += 1 },
                interrupted: { XCTFail("should not interrupt") },
                value: { received += [$0.action] })
            .start()
        XCTAssertNil(sut.token)
        XCTAssertEqual(["1", "1", "2", "3", "5", "8", "13", "21", "34", "55"], received)
        XCTAssertEqual(1, completion)
    }
}
