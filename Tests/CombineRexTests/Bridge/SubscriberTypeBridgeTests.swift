#if canImport(Combine)
import Combine
import CombineRex
import SwiftRex
import XCTest

class SubscriberTypeBridgeTests: XCTestCase {
    func testSubscriberTypeToSubscriberOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let publisher = BlockPublisher<String, SomeError> { subscriber in
            _ = subscriber.receive("test")
            subscriber.receive(completion: .finished)
        }

        publisher.receive(
            subscriber: SubscriberType<String, SomeError>(
                onValue: { string in
                    XCTAssertEqual("test", string)
                    shouldCallClosureValue.fulfill()
                },
                onCompleted: { error in
                    if let error = error {
                        XCTFail("Unexpected error: \(error)")
                    }
                    shouldCallClosureCompleted.fulfill()
                }
            )
        )

        wait(for: [shouldCallClosureValue, shouldCallClosureCompleted], timeout: 0.1)
    }

    func testSubscriberTypeToSubscriberOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let publisher = BlockPublisher<String, SomeError> { subscriber in
            _ = subscriber.receive("test")
            subscriber.receive(completion: .failure(someError))
        }

        publisher.receive(
            subscriber: SubscriberType<String, SomeError>(
                onValue: { string in
                    XCTAssertEqual("test", string)
                    shouldCallClosureValue.fulfill()
                },
                onCompleted: { error in
                    guard let error = error else {
                        XCTFail("Unexpected completion")
                        return
                    }
                    XCTAssertEqual(someError, error)
                    shouldCallClosureError.fulfill()
                }
            )
        )

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }

    func testSubscriberToSubscriberTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let publisherType = PublisherType<String, SomeError> { subscriber in
            let subscription = FooCombineSubscription { }
            subscriber.receive(subscription: subscription)
            subscriber.onValue("test")
            subscriber.onCompleted(nil)
            return FooSubscription { subscription.cancel() }
        }

        _ = publisherType.subscribe(AnySubscriber<String, SomeError>(
            receiveSubscription: { _ in },
            receiveValue: { string in
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
                return .none
            },
            receiveCompletion: { completion in
                guard case .finished = completion else {
                    XCTFail("Unexpected error")
                    return
                }
                shouldCallClosureCompleted.fulfill()
            }
        ).asSubscriberType())

        wait(for: [shouldCallClosureValue, shouldCallClosureCompleted], timeout: 0.1)
    }

    func testSubscriberToSubscriberTypeOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let publisherType = PublisherType<String, SomeError> { subscriber in
            subscriber.onValue("test")
            subscriber.onCompleted(someError)
            return FooSubscription { }
        }

        _ = publisherType.subscribe(AnySubscriber<String, SomeError>(
            receiveSubscription: { _ in },
            receiveValue: { string in
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
                return .none
            },
            receiveCompletion: { completion in
                guard case let .failure(error) = completion else {
                    XCTFail("Unexpected completion")
                    return
                }
                XCTAssertEqual(someError, error)
                shouldCallClosureError.fulfill()
            }
        ).asSubscriberType())

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }
}
#endif
