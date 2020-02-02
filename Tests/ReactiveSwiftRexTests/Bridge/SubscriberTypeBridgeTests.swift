import Nimble
import ReactiveSwift
import ReactiveSwiftRex
import SwiftRex
import XCTest

class SubscriberTypeBridgeTests: XCTestCase {
    func testSubscriberTypeToObserverOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let signalProducer = SignalProducer<String, SomeError> { observer, _ in
            observer.send(value: "test")
            observer.sendCompleted()
        }

        _ = signalProducer.start(
            SubscriberType<String, SomeError>(
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
            ).asObserver()
        )

        wait(for: [shouldCallClosureValue, shouldCallClosureCompleted], timeout: 0.1)
    }

    func testSubscriberTypeToObserverOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let signalProducer = SignalProducer<String, SomeError> { observer, _ in
            observer.send(value: "test")
            observer.send(error: someError)
        }

        _ = signalProducer.start(
            SubscriberType<String, SomeError>(
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
            ).asObserver()
        )

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }

    func testObserverToSubscriberTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let publisherType = PublisherType<String, SomeError> { subscriber in
            subscriber.onValue("test")
            subscriber.onCompleted(nil)
            return FooSubscription { }
        }

        _ = publisherType.subscribe(Signal<String, SomeError>.Observer { action in
            switch action {
            case let .value(string):
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            case let .failed(error):
                XCTFail("Unexpected error: \(error)")
            case .completed:
                shouldCallClosureCompleted.fulfill()
            case .interrupted:
                XCTFail("Unexpected interruption")
            }
        }.asSubscriberType())

        wait(for: [shouldCallClosureValue, shouldCallClosureCompleted], timeout: 0.1)
    }

    func testObserverToSubscriberTypeOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let publisherType = PublisherType<String, SomeError> { subscriber in
            subscriber.onValue("test")
            subscriber.onCompleted(someError)
            return FooSubscription { }
        }

        _ = publisherType.subscribe(Signal<String, SomeError>.Observer { action in
            switch action {
            case let .value(string):
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            case let .failed(error):
                XCTAssertEqual(someError, error)
                shouldCallClosureError.fulfill()
            case .completed:
                XCTFail("Unexpected completion")
            case .interrupted:
                XCTFail("Unexpected interruption")
            }
        }.asSubscriberType())

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }
}
