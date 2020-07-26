#if canImport(Combine)
import Combine
import CombineRex
import SwiftRex
import XCTest

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class EffectTests: XCTestCase {
    func testInitWithCancellation() {
        let sut = Effect(upstream: [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { .dispatch($0) }.publisher, cancellationToken: "token")
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertEqual("token", sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testInitWithoutCancellation() {
        let sut = Effect(upstream: [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { .dispatch($0) }.publisher)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testInitWithoutCancellationButAddItLater() {
        let sut = Effect(upstream: [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { .dispatch($0) }.publisher).cancellation(token: "token")
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertEqual("token", sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testDoNothing() {
        let sut = Effect<Int>.doNothing
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertEqual([], received)
        XCTAssertEqual([.finished], completion)
    }

    func testJust() {
        let sut = Effect<Int>.just(42)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertEqual([42], received)
        XCTAssertEqual([.finished], completion)
    }

    func testSequenceArray() {
        let sut = Effect.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testSequenceVariadics() {
        let sut = Effect.sequence(1, 1, 2, 3, 5, 8, 13, 21, 34, 55)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testPromise() {
        let sut = Effect<Int>.promise { callback in
            callback(.dispatch(42))
        }
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertEqual([42], received)
        XCTAssertEqual([.finished], completion)
    }

    func testAsEffectWithCancellation() {
        let sut = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].publisher.asEffect(dispatcher: .here(), cancellationToken: "token")
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertEqual("token", sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testAsEffectWithoutCancellation() {
        let sut = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].publisher.asEffect(dispatcher: .here())
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testFireAndForgetClosure() {
        let calledClosure = expectation(description: "should have called fire and forget closure")
        let sut = Effect<Int>.fireAndForget {
            calledClosure.fulfill()
        }
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()

        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([], received)
        XCTAssertEqual([.finished], completion)
    }

    func testFireAndForgetPublisher() {
        let calledClosure = expectation(description: "should have called fire and forget closure")
        let publisher = Just("test").handleEvents(receiveOutput: { value in
            XCTAssertEqual(value, "test")
            calledClosure.fulfill()
        })
        let sut = Effect<Int>.fireAndForget(publisher)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([], received)
        XCTAssertEqual([.finished], completion)
    }

    func testFireAndForgetPublisherCatchErrorSuccess() {
        let calledClosure = expectation(description: "should have called fire and forget closure")
        let publisher = Result<String, Error>.success("test").publisher.handleEvents(receiveOutput: { value in
            XCTAssertEqual(value, "test")
            calledClosure.fulfill()
        })
        let sut = Effect<Int>.fireIgnoreOutput(
            publisher,
            catchErrors: { error in
                XCTFail(error.localizedDescription)
                return nil
            }
        )
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([], received)
        XCTAssertEqual([.finished], completion)
    }

    func testFireAndForgetPublisherCatchErrorFailure() {
        let calledClosure = expectation(description: "should have called fire and forget error closure")
        let someError = SomeError()
        let publisher = Result<String, Error>.failure(someError).publisher.handleEvents(
            receiveOutput: { value in
                XCTFail("Success was not expected")
            },
            receiveCompletion: { completion in
                guard case let .failure(error) = completion else {
                    XCTFail("Success was not expected")
                    return
                }

                XCTAssertEqual(error as? SomeError, someError)
                calledClosure.fulfill()
            }
        )
        let sut = Effect<Int>.fireIgnoreOutput(
            publisher,
            catchErrors: { error in
                XCTAssertEqual(error as? SomeError, someError)
                return .dispatch(42)
            }
        )
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([42], received)
        XCTAssertEqual([.finished], completion)
    }

    func testMergeTwo() {
        let first = Effect.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        let second = Effect.just(89)
        let sut = Effect.merge(first, second)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual([.finished], completion)
    }

    func testMergeThree() {
        let first = Effect.sequence([1, 1, 2, 3, 5, 8, 13, 21])
        let second = Effect.just(34)
        let third = Effect.sequence([55, 89])
        let sut = Effect.merge(first, second, third)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual([.finished], completion)
    }

    func testMergeFour() {
        let first = Effect.sequence([1, 1, 2, 3, 5, 8, 13, 21])
        let second = Effect.just(34)
        let third = Effect.sequence([55, 89])
        let fourth = Effect.sequence([144])
        let sut = Effect.merge(first, second, third, fourth)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144], received)
        XCTAssertEqual([.finished], completion)
    }

    func testMergeFive() {
        let first = Effect.sequence([1, 1, 2, 3, 5, 8, 13, 21])
        let second = Effect.just(34)
        let third = Effect.sequence([55, 89])
        let fourth = Effect.sequence([144])
        let fifth = Effect.just(233)
        let sut = Effect.merge(first, second, third, fourth, fifth)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233], received)
        XCTAssertEqual([.finished], completion)
    }

    func testPrepend() {
        let first = Effect.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        let second = Effect.just(89)
        let sut = second.prepend(first)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual([.finished], completion)
    }

    func testAppend() {
        let first = Effect.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        let second = Effect.just(89)
        let sut = first.append(second)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual([.finished], completion)
    }

    func testFMap() {
        let numbers = Effect.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        let sut = numbers.fmap(String.init)
        var completion = [Subscribers.Completion<Never>]()
        var received = [String]()
        _ = sut.sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.cancellationToken)
        XCTAssertEqual(["1", "1", "2", "3", "5", "8", "13", "21", "34", "55"], received)
        XCTAssertEqual([.finished], completion)
    }

}
#endif
