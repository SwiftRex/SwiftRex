import ReactiveSwift
import ReactiveSwiftRex
import SwiftRex
import XCTest

class EffectTests: XCTestCase {
    func testInitWithCancellation() {
        let sut = Effect(upstream: SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]), cancellationToken: "token")
        var completion = 0
        var received = [Int]()
        _ = sut.producer.on(
            completed: { completion += 1 },
            interrupted: { XCTFail("should not interrupt") },
            value: { received += [$0] })
            .start()
        XCTAssertEqual("token", sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testInitWithoutCancellation() {
        let sut = Effect(upstream: SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]))
        var completion = 0
        var received = [Int]()
        _ = sut.producer.on(
            completed: { completion += 1 },
            interrupted: { XCTFail("should not interrupt") },
            value: { received += [$0] })
            .start()
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testInitWithoutCancellationButAddItLater() {
        let sut = Effect(upstream: SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])).cancellation(token: "token")
        var completion = 0
        var received = [Int]()
        _ = sut.producer.on(
            completed: { completion += 1 },
            interrupted: { XCTFail("should not interrupt") },
            value: { received += [$0] })
            .start()
        XCTAssertEqual("token", sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testDoNothing() {
        let sut = Effect<Int>.doNothing
        var completion = 0
        var received = [Int]()
        _ = sut.producer.on(
            completed: { completion += 1 },
            interrupted: { XCTFail("should not interrupt") },
            value: { received += [$0] })
            .start()
        XCTAssertEqual([], received)
        XCTAssertEqual(1, completion)
    }

    func testJust() {
        let sut = Effect<Int>.just(42)
        var completion = 0
        var received = [Int]()
        _ = sut.producer.on(
            completed: { completion += 1 },
            interrupted: { XCTFail("should not interrupt") },
            value: { received += [$0] })
            .start()
        XCTAssertEqual([42], received)
        XCTAssertEqual(1, completion)
    }

    func testSequenceArray() {
        let sut = Effect.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        var completion = 0
        var received = [Int]()
        _ = sut.producer.on(
            completed: { completion += 1 },
            interrupted: { XCTFail("should not interrupt") },
            value: { received += [$0] })
            .start()
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testSequenceVariadics() {
        let sut = Effect.sequence(1, 1, 2, 3, 5, 8, 13, 21, 34, 55)
        var completion = 0
        var received = [Int]()
        _ = sut.producer.on(
            completed: { completion += 1 },
            interrupted: { XCTFail("should not interrupt") },
            value: { received += [$0] })
            .start()
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testPromise() {
        let sut = Effect<Int>.promise { callback in
            callback(42)
            return AnyDisposable()
        }
        var completion = 0
        var received = [Int]()
        _ = sut.producer.on(
            completed: { completion += 1 },
            interrupted: { XCTFail("should not interrupt") },
            value: { received += [$0] })
            .start()
        XCTAssertEqual([42], received)
        XCTAssertEqual(1, completion)
    }

    func testAsEffectWithCancellation() {
        let sut = SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]).asEffect(cancellationToken: "token")
        var completion = 0
        var received = [Int]()
        _ = sut.producer.on(
            completed: { completion += 1 },
            interrupted: { XCTFail("should not interrupt") },
            value: { received += [$0] })
            .start()
        XCTAssertEqual("token", sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testAsEffectWithoutCancellation() {
        let sut = SignalProducer([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]).asEffect
        var completion = 0
        var received = [Int]()
        _ = sut.producer.on(
            completed: { completion += 1 },
            interrupted: { XCTFail("should not interrupt") },
            value: { received += [$0] })
            .start()
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }
}
