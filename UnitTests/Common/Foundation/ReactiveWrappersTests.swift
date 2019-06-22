import Foundation
@testable import SwiftRex
import XCTest

class ReactiveWrappersTests: XCTestCase {
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
}
