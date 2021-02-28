import CombineX
import CombineXRex
import CXFoundation
import SwiftRex
import XCTest

class PublisherTypeBridgeTests: XCTestCase {
    func testPublisherTypeToPublisherOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let publisherType = PublisherType<String, Error> { subscriber in
            subscriber.onValue("test")
            subscriber.onCompleted(nil)
            return FooSubscription { }
        }

        publisherType.receive(subscriber: CombineX.AnySubscriber<String, Error>(
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
            })
        )

        wait(for: [shouldCallClosureValue, shouldCallClosureCompleted], timeout: 0.1)
    }

    func testPublisherTypeToObservableOnValueMap() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let publisherType = PublisherType<Int, Error> { subscriber in
            subscriber.onValue(42)
            subscriber.onCompleted(nil)
            return FooSubscription { }
        }

        PublisherType<String, Error>.lift { (int: Int) -> String in "\(int)" }(publisherType).receive(subscriber: CombineX.AnySubscriber(
            receiveSubscription: { _ in },
            receiveValue: { string in
                XCTAssertEqual("42", string)
                shouldCallClosureValue.fulfill()
                return .none
            },
            receiveCompletion: { completion in
                guard case .finished = completion else {
                    XCTFail("Unexpected error")
                    return
                }
                shouldCallClosureCompleted.fulfill()
            })
        )

        wait(for: [shouldCallClosureValue, shouldCallClosureCompleted], timeout: 0.1)
    }

    func testPublisherTypeToPublisherOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let publisherType = PublisherType<String, Error> { subscriber in
            subscriber.onValue("test")
            subscriber.onCompleted(someError)
            return FooSubscription { }
        }

        publisherType.receive(subscriber: CombineX.AnySubscriber(
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

                XCTAssertEqual(someError, error as! SomeError)
                shouldCallClosureError.fulfill()
            })
        )

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }

    func testPublisherToPublisherTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let publisher = BlockPublisher<String, SomeError> { subscriber in
            _ = subscriber.receive("test")
            subscriber.receive(completion: .finished)
        }

        _ = publisher.asPublisherType().subscribe(SubscriberType(
            onValue: { string in
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            },
            onCompleted: { error in
                if let error = error {
                    XCTFail("Unexpected error: \(error)")
                }
                shouldCallClosureCompleted.fulfill()
            }))

        wait(for: [shouldCallClosureValue, shouldCallClosureCompleted], timeout: 0.1)
    }

    func testPublisherToPublisherTypeOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let publisher = BlockPublisher<String, SomeError> { subscriber in
            _ = subscriber.receive("test")
            subscriber.receive(completion: .failure(someError))
        }

        _ = publisher.asPublisherType().subscribe(SubscriberType(
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
            }))

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }
}
