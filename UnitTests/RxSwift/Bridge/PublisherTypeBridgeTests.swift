import RxSwift
import SwiftRex
import SwiftRexForRx
import XCTest

class PublisherTypeBridgeTests: XCTestCase {
    func testPublisherTypeToObservableOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let publisherType = SwiftRex.PublisherType<String, Error> { subscriber in
            subscriber.onValue("test")
            subscriber.onCompleted()
            return FooSubscription()
        }

        _ = publisherType.subscribe(
            onNext: { string in
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            },
            onError: { error in
                XCTFail("Unexpected error: \(error)")
            },
            onCompleted: {
                shouldCallClosureCompleted.fulfill()
            })

        wait(for: [shouldCallClosureValue, shouldCallClosureCompleted], timeout: 0.1)
    }

    func testPublisherTypeToObservableOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let publisherType = SwiftRex.PublisherType<String, Error> { subscriber in
            subscriber.onValue("test")
            subscriber.onError(someError)
            return FooSubscription()
        }

        _ = publisherType.subscribe(
            onNext: { string in
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            },
            onError: { error in
                XCTAssertEqual(someError, error as! SomeError)
                shouldCallClosureError.fulfill()
            },
            onCompleted: {
                XCTFail("Unexpected completion")
            })

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }

    func testObservableToPublisherTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let observable = Observable<String>.create { observer in
            observer.onNext("test")
            observer.onCompleted()
            return Disposables.create()
        }

        _ = observable.asPublisher().subscribe(SubscriberType(
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

    func testObservableToPublisherTypeOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let observable = Observable<String>.create { observer in
            observer.onNext("test")
            observer.onError(someError)
            return Disposables.create()
        }

        _ = observable.asPublisher().subscribe(SubscriberType(
            onValue: { string in
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            },
            onCompleted: { error in
                guard let error = error else {
                    XCTFail("Unexpected completion")
                    return
                }

                XCTAssertEqual(someError, error as! SomeError)
                shouldCallClosureError.fulfill()
            }))

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }
}
