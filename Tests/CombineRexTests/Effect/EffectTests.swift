#if canImport(Combine)
import Combine
import CombineRex
import SwiftRex
import XCTest

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class EffectTests: XCTestCase {
    func testInitWithCancellation() {
        let sut = Effect(upstream: [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].publisher, cancellationToken: "token")
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0] })
        XCTAssertEqual("token", sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testInitWithoutCancellation() {
        let sut = Effect(upstream: [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].publisher)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testInitWithoutCancellationButAddItLater() {
        let sut = Effect(upstream: [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].publisher).cancellation(token: "token")
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0] })
        XCTAssertEqual("token", sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testDoNothing() {
        let sut = Effect<Int>.doNothing
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0] })
        XCTAssertEqual([], received)
        XCTAssertEqual([.finished], completion)
    }

    func testJust() {
        let sut = Effect<Int>.just(42)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0] })
        XCTAssertEqual([42], received)
        XCTAssertEqual([.finished], completion)
    }

    func testSequenceArray() {
        let sut = Effect.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testSequenceVariadics() {
        let sut = Effect.sequence(1, 1, 2, 3, 5, 8, 13, 21, 34, 55)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testPromise() {
        let sut = Effect<Int>.promise { callback in
            callback(42)
        }
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0] })
        XCTAssertEqual([42], received)
        XCTAssertEqual([.finished], completion)
    }

    func testAsEffectWithCancellation() {
        let sut = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].publisher.asEffect(cancellationToken: "token")
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0] })
        XCTAssertEqual("token", sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testAsEffectWithoutCancellation() {
        let sut = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].publisher.asEffect
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }
}
#endif
