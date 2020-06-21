import RxSwift
import RxSwiftRex
import SwiftRex
import XCTest

class EffectTests: XCTestCase {
    func testInitWithCancellation() {
        let sut = Effect(upstream: Observable<Int>.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]), cancellationToken: "token")
        var completion = 0
        var received = [Int]()
        _ = sut.subscribe(onNext: { received += [$0] },
                          onError: { _ in XCTFail("should not fail") },
                          onCompleted: { completion += 1 })
        XCTAssertEqual("token", sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testInitWithoutCancellation() {
        let sut = Effect(upstream: Observable<Int>.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]))
        var completion = 0
        var received = [Int]()
        _ = sut.subscribe(onNext: { received += [$0] },
                          onError: { _ in XCTFail("should not fail") },
                          onCompleted: { completion += 1 })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testInitWithoutCancellationButAddItLater() {
        let sut = Effect(upstream: Observable<Int>.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])).cancellation(token: "token")
        var completion = 0
        var received = [Int]()
        _ = sut.subscribe(onNext: { received += [$0] },
                          onError: { _ in XCTFail("should not fail") },
                          onCompleted: { completion += 1 })
        XCTAssertEqual("token", sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testDoNothing() {
        let sut = Effect<Int>.doNothing
        var completion = 0
        var received = [Int]()
        _ = sut.subscribe(onNext: { received += [$0] },
                          onError: { _ in XCTFail("should not fail") },
                          onCompleted: { completion += 1 })
        XCTAssertEqual([], received)
        XCTAssertEqual(1, completion)
    }

    func testJust() {
        let sut = Effect<Int>.just(42)
        var completion = 0
        var received = [Int]()
        _ = sut.subscribe(onNext: { received += [$0] },
                          onError: { _ in XCTFail("should not fail") },
                          onCompleted: { completion += 1 })
        XCTAssertEqual([42], received)
        XCTAssertEqual(1, completion)
    }

    func testSequenceArray() {
        let sut = Effect.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        var completion = 0
        var received = [Int]()
        _ = sut.subscribe(onNext: { received += [$0] },
                          onError: { _ in XCTFail("should not fail") },
                          onCompleted: { completion += 1 })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testSequenceVariadics() {
        let sut = Effect.sequence(1, 1, 2, 3, 5, 8, 13, 21, 34, 55)
        var completion = 0
        var received = [Int]()
        _ = sut.subscribe(onNext: { received += [$0] },
                          onError: { _ in XCTFail("should not fail") },
                          onCompleted: { completion += 1 })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testPromise() {
        let sut = Effect<Int>.promise { callback in
            callback(42)
            return Disposables.create()
        }
        var completion = 0
        var received = [Int]()
        _ = sut.subscribe(onNext: { received += [$0] },
                          onError: { _ in XCTFail("should not fail") },
                          onCompleted: { completion += 1 })
        XCTAssertEqual([42], received)
        XCTAssertEqual(1, completion)
    }

    func testAsEffectWithCancellation() {
        let sut = Observable<Int>.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]).asEffect(cancellationToken: "token")
        var completion = 0
        var received = [Int]()
        _ = sut.subscribe(onNext: { received += [$0] },
                          onError: { _ in XCTFail("should not fail") },
                          onCompleted: { completion += 1 })
        XCTAssertEqual("token", sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testAsEffectWithoutCancellation() {
        let sut = Observable<Int>.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]).asEffect
        var completion = 0
        var received = [Int]()
        _ = sut.subscribe(onNext: { received += [$0] },
                          onError: { _ in XCTFail("should not fail") },
                          onCompleted: { completion += 1 })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }
}
