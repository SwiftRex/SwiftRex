#if canImport(Combine)
import Combine
import CombineRex
import SwiftRex
import XCTest

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class EffectTests: XCTestCase {
    func testInitWithCancellation() {
        let sut = Effect<Void, Int>(token: "token") { _ in [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }.publisher }
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertEqual("token", sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testInitWithoutCancellation() {
        let sut = Effect<Void, Int> { _ in [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }.publisher }
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testInitWithoutCancellationNoDependencies() {
        let sut = Effect<Void, Int>([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }.publisher)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testInitWithoutCancellationIgnoringDependencies() {
        let sut: Effect<Int, Int> = Effect<Void, Int>(
            [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }.publisher
        ).ignoringDependencies()
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (42), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testInitWithCancellationNoDependenciesFromPublisherDispatchedAction() {
        let sut = Effect<Void, Int>(token: "token", effect: [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }.publisher)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertEqual("token", sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testInitWithCancellationIgnoringDependencies() {
        let sut: Effect<String, Int> = Effect<Void, Int>(
            token: "token",
            effect: [1, 1, 2, 3, 5, 8, 13, 21, 34, 55]
                .map { DispatchedAction($0) }
                .publisher
        )
        .ignoringDependencies()
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (""), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertEqual("token", sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testInitWithCancellationIgnoringDependenciesDoNothing() {
        let sut: Effect<String, Int> = Effect<Void, Int>.doNothing
            .ignoringDependencies()
        XCTAssertNil(sut.token)
        XCTAssertNil(sut.run((dependencies: (""), toCancel: { _ in FireAndForget { } })))
    }

    func testDoNothing() {
        let sut = Effect<Void, Int>.doNothing
        XCTAssertNil(sut.token)
        XCTAssertNil(sut.run((dependencies: (), toCancel: { _ in FireAndForget { } })))
    }

    func testJust() {
        let sut = Effect<Void, Int>.just(42)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertEqual([42], received)
        XCTAssertEqual([.finished], completion)
    }

    func testJustWithDependencies() {
        let sut = Effect<Int, Int>.just { context in
            context.dependencies + 42
        }
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: 1, toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertEqual([43], received)
        XCTAssertEqual([.finished], completion)
    }

    func testSequenceArray() {
        let sut = Effect<Void, Int>.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testSequenceVariadics() {
        let sut = Effect<Void, Int>.sequence(1, 1, 2, 3, 5, 8, 13, 21, 34, 55)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testPromise() {
        let sut = Effect<Int, String>.promise(token: "token") { context, callback in
            callback(String(context.dependencies + 1))
        }
        var completion = [Subscribers.Completion<Never>]()
        var received = [String]()
        _ = sut
            .run((dependencies: 42, toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertEqual(["43"], received)
        XCTAssertEqual([.finished], completion)
    }

    func testAsEffectWithCancellation() {
        let sut = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].publisher.asEffect(token: "token")
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertEqual("token", sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testAsEffectWithoutCancellation() {
        let sut = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].publisher.asEffect(dispatcher: .here())
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual([.finished], completion)
    }

    func testFireAndForgetClosure() {
        let calledClosure = expectation(description: "should have called fire and forget closure")
        let sut = Effect<Void, Int>.fireAndForget {
            calledClosure.fulfill()
        }
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()

        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
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
        let sut = Effect<Void, Int>.fireAndForget(publisher)
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
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
        let sut = Effect<Void, Int>.fireAndForget(
            publisher,
            catchErrors: { error in
                XCTFail(error.localizedDescription)
                return nil
            }
        )
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([], received)
        XCTAssertEqual([.finished], completion)
    }

    func testFireAndForgetPublisherCatchErrorFailure() {
        let calledClosure = expectation(description: "should have called fire and forget error closure")
        let someError = SomeError()
        let publisher = Result<String, Error>.failure(someError).publisher.handleEvents(
            receiveOutput: { _ in
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
        let sut = Effect<Void, Int>.fireAndForget(
            publisher,
            catchErrors: { error in
                XCTAssertEqual(error as? SomeError, someError)
                return .init(42)
            }
        )
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([42], received)
        XCTAssertEqual([.finished], completion)
    }

    func testMergeTwo() {
        let first = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }.publisher
        let second = Just(DispatchedAction(89))
        let sut = Effect<Void, Int>(Publishers.Merge(first, second))
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual([.finished], completion)
    }

    func testMergeThree() {
        let first = [1, 1, 2, 3, 5, 8, 13, 21].map { DispatchedAction($0) }.publisher
        let second = Just(DispatchedAction(34))
        let third = [55, 89].map { DispatchedAction($0) }.publisher
        let sut = Effect<Void, Int>(Publishers.Merge3(first, second, third))
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual([.finished], completion)
    }

    func testPrepend() {
        let first = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }.publisher
        let second = Just(DispatchedAction(89))
        let sut = Effect(second.prepend(first))
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual([.finished], completion)
    }

    func testAppend() {
        let first = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }.publisher
        let second = Just(DispatchedAction(89))
        let sut = Effect(first.append(second))
        var completion = [Subscribers.Completion<Never>]()
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual([.finished], completion)
    }

    func testFMap() {
        let numbers = Effect<Void, Int>.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        let sut = numbers.map(String.init)
        var completion = [Subscribers.Completion<Never>]()
        var received = [String]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .sink(receiveCompletion: { completion += [$0] }, receiveValue: { received += [$0.action] })
        XCTAssertNil(sut.token)
        XCTAssertEqual(["1", "1", "2", "3", "5", "8", "13", "21", "34", "55"], received)
        XCTAssertEqual([.finished], completion)
    }

    func testFMapDoNothing() {
        let numbersDoNothing = Effect<Void, Int>.doNothing
        let sut = numbersDoNothing.map(String.init)
        let possibleEffect = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))
        XCTAssertNil(sut.token)
        XCTAssertNil(possibleEffect)
    }

    func testFMapCancellation() {
        let shouldCallToCancel = expectation(description: "to cancel should have been called")
        let shouldHaveCancelledThePublisher = expectation(description: "publisher cancellation should have been called")
        let numbers = Effect<Void, Int>(token: "token") { context in
            [1, 1, 2, 3, 5, 8, 13, 21, 34, 55]
                .publisher
                .throttle(for: .milliseconds(20), scheduler: DispatchQueue.main, latest: true)
                .map { DispatchedAction($0) }
                .prepend(context.toCancel("123"))
        }
        let sut = numbers.map(String.init)
        _ = sut
            .run((dependencies: (), toCancel: { token in
                XCTAssertEqual("123", token)
                shouldCallToCancel.fulfill()
                return FireAndForget { }
            }))?
            .handleEvents(receiveCancel: {
                shouldHaveCancelledThePublisher.fulfill()
            })
            .sink(receiveCompletion: { _ in XCTFail("should not complete") }, receiveValue: { _ in })

        XCTAssertEqual("token", sut.token)
        wait(for: [shouldCallToCancel, shouldHaveCancelledThePublisher], timeout: 0.1)
    }
}
#endif
