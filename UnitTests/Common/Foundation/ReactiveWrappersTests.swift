import Foundation
import Nimble
@testable import SwiftRex
import XCTest

class ReactiveWrappersTests: XCTestCase {
    // MARK: - Subscriber
    func testSubscriberTypeOnValue() {
        let shouldCallClosure = expectation(description: "Closure should be called")
        let onValue: (String) -> Void = { string in
            XCTAssertEqual("test", string)
            shouldCallClosure.fulfill()
        }
        let subscriberType = SubscriberType<String, Error>(
            onValue: onValue,
            onCompleted: { XCTFail("Unexpected completion. Error? \(String(describing: $0))") }
        )
        subscriberType.onValue("test")

        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    func testSubscriberTypeOnError() {
        let shouldCallClosure = expectation(description: "Closure should be called")
        let someError = SomeError()
        let onError: (Error?) -> Void = { error in
            XCTAssertEqual(someError, error as! SomeError)
            shouldCallClosure.fulfill()
        }
        let subscriberType = SubscriberType<String, Error>(
            onValue: { XCTFail("Unexpected value \($0)") },
            onCompleted: onError
        )
        subscriberType.onCompleted(someError)

        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    func testSubscriberTypeAssertNoFailureOnValue() {
        let shouldCallClosure = expectation(description: "Closure should be called")
        let onError: (Error?) -> Void = { never in
            XCTAssertNil(never)
            shouldCallClosure.fulfill()
        }
        let subscriberType = SubscriberType<String, Error>(
            onValue: { XCTFail("Unexpected value \($0)") },
            onCompleted: onError
        ).assertNoFailure()
        subscriberType.onCompleted(nil)

        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    func testSubscriberTypeAssertNoFailureOnErrorAfter() {
        let shouldCallClosureValue = expectation(description: "Closure value should be called")
        let shouldCallClosureError = expectation(description: "Closure error should be called")
        let someError = SomeError()
        let onValue: (String) -> Void = { string in
            XCTAssertEqual(string, "a")
            shouldCallClosureValue.fulfill()
        }
        let onError: (Error?) -> Void = { error in
            XCTAssertEqual(someError, error as! SomeError)
            shouldCallClosureError.fulfill()
        }
        let subscriberType = SubscriberType<String, Error>(
            onValue: onValue,
            onCompleted: onError
        )

        let subscriberTypeUnfailable = subscriberType.assertNoFailure()

        subscriberTypeUnfailable.onValue("a")
        subscriberType.onCompleted(someError)

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }

    // MARK: - Publisher
    func testPublisherTypeOnValue() {
        let shouldCallClosure = expectation(description: "Closure should be called")
        let subscriberType = SubscriberType<String, Error>(onValue: { string in
            XCTAssertEqual("test", string)
            shouldCallClosure.fulfill()
        })

        let publisherType = PublisherType<String, Error> { subscriber in
            subscriber.onValue("test")
            return FooSubscription()
        }

        _ = publisherType.subscribe(subscriberType)

        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    func testPublisherTypeOnError() {
        let shouldCallClosure = expectation(description: "Closure should be called")
        let someError = SomeError()
        let subscriberType = SubscriberType<String, Error>(
            onCompleted: { error in
                XCTAssertEqual(someError, error as! SomeError)
                shouldCallClosure.fulfill()
            }
        )

        let publisherType = PublisherType<String, Error> { subscriber in
            subscriber.onCompleted(someError)
            return FooSubscription()
        }

        _ = publisherType.subscribe(subscriberType)

        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    func testPublisherTypeAssertNoFailureOnValue() {
        let shouldCallClosure = expectation(description: "Closure should be called")
        let subscriberType = SubscriberType<String, Never>(onValue: { string in
            XCTAssertEqual("test", string)
            shouldCallClosure.fulfill()
        })

        let publisherType = PublisherType<String, Error> { subscriber in
            subscriber.onValue("test")
            return FooSubscription()
        }.assertNoFailure()

        _ = publisherType.subscribe(subscriberType)

        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    func testPublisherTypeAssertNoFailureOnError() {
        let shouldCallClosure = expectation(description: "Closure should be called")
        let someError = SomeError()
        let subscriberType = SubscriberType<String, Never>(onValue: { string in
            XCTAssertEqual("test", string)
            shouldCallClosure.fulfill()
        })

        let publisherType = PublisherType<String, Error> { subscriber in
            expect {
                subscriber.onValue("test")
                return subscriber.onCompleted(someError)
            }.to(throwAssertion())
            return FooSubscription()
        }.assertNoFailure()

        _ = publisherType.subscribe(subscriberType)

        wait(for: [shouldCallClosure], timeout: 0.1)
    }
    // MARK: - Subject
    func testSubjectTypeOnValue() {
        let shouldCallClosure = expectation(description: "Closure should be called")
        let subscriberType = SubscriberType<String, Error>(onValue: { string in
            XCTAssertEqual("test", string)
            shouldCallClosure.fulfill()
        })

        let publisherType = PublisherType<String, Error> { subscriber in
            subscriber.onValue("test")
            return FooSubscription()
        }

        let subjectType = SubjectType(publisher: publisherType, subscriber: subscriberType)

        _ = subjectType.publisher.subscribe(subjectType.subscriber)

        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    func testSubjectTypeOnError() {
        let shouldCallClosure = expectation(description: "Closure should be called")
        let someError = SomeError()
        let subscriberType = SubscriberType<String, Error>(onCompleted: { error in
            XCTAssertEqual(someError, error as! SomeError)
            shouldCallClosure.fulfill()
        })

        let publisherType = PublisherType<String, Error> { subscriber in
            subscriber.onCompleted(someError)
            return FooSubscription()
        }

        let subjectType = SubjectType(publisher: publisherType, subscriber: subscriberType)

        _ = subjectType.publisher.subscribe(subjectType.subscriber)

        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    // MARK: - Replay Subject
    func testReplaySubjectTypeOnValue() {
        let shouldCallClosure = expectation(description: "Closure should be called")
        let subscriberType = SubscriberType<String, Error>(onValue: { string in
            XCTAssertEqual("test", string)
            shouldCallClosure.fulfill()
        })

        let publisherType = PublisherType<String, Error> { subscriber in
            subscriber.onValue("test")
            return FooSubscription()
        }

        let subjectType = ReplayLastSubjectType(
            publisher: publisherType,
            subscriber: subscriberType,
            value: { "constant" }
        )

        _ = subjectType.publisher.subscribe(subjectType.subscriber)

        XCTAssertEqual("constant", subjectType.value())
        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    func testReplaySubjectTypeOnError() {
        let shouldCallClosure = expectation(description: "Closure should be called")
        let someError = SomeError()
        let subscriberType = SubscriberType<String, Error>(onCompleted: { error in
            XCTAssertEqual(someError, error as! SomeError)
            shouldCallClosure.fulfill()
        })

        let publisherType = PublisherType<String, Error> { subscriber in
            subscriber.onCompleted(someError)
            return FooSubscription()
        }

        let subjectType = ReplayLastSubjectType(
            publisher: publisherType,
            subscriber: subscriberType,
            value: { "constant" }
        )

        _ = subjectType.publisher.subscribe(subjectType.subscriber)

        XCTAssertEqual("constant", subjectType.value())
        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    func testReplaySubjectTypeMutate() {
        let shouldCallClosure = expectation(description: "Closure should be called")
        shouldCallClosure.expectedFulfillmentCount = 2
        var time = 1
        let subscriberType = SubscriberType<String, Error>(onValue: { string in
            switch time {
            case 1: XCTAssertEqual(string, "initial")
            case 2: XCTAssertEqual(string, "changed")
            default: XCTFail("Called too many times")
            }
            shouldCallClosure.fulfill()
            time += 1
        })

        let publisherType = PublisherType<String, Error> { subscriber in
            subscriber.onValue("initial")
            return FooSubscription()
        }

        let subjectType = ReplayLastSubjectType(
            publisher: publisherType,
            subscriber: subscriberType,
            value: { "constant" }
        )

        _ = subjectType.publisher.subscribe(subjectType.subscriber)

        let oldValueDecorated = subjectType.mutate { value -> String in
            let oldDecorated = "*" + value + "*"
            value = "changed"
            return oldDecorated
        }

        XCTAssertEqual("constant", subjectType.value())
        XCTAssertEqual("*constant*", oldValueDecorated)
        wait(for: [shouldCallClosure], timeout: 0.1)
    }
}
