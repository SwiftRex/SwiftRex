import Nimble
import RxSwift
import RxSwiftRex
import SwiftRex
import XCTest

class SubscriberTypeBridgeTests: XCTestCase {
    func testSubscriberTypeToObserverOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let observable = Observable<String>.create { observer in
            observer.onNext("test")
            observer.onCompleted()
            return Disposables.create()
        }

        _ = observable.subscribe(
            SubscriberType<String, Error>(
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

        let observable = Observable<String>.create { observer in
            observer.onNext("test")
            observer.onError(someError)
            return Disposables.create()
        }

        _ = observable.subscribe(
            SubscriberType<String, Error>(
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
                }
            ).asObserver()
        )

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }

    func testObserverToSubscriberTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let publisherType = PublisherType<String, Error> { subscriber in
            subscriber.onValue("test")
            subscriber.onCompleted()
            return FooSubscription { }
        }

        _ = publisherType.subscribe(AnyObserver<String> { event in
            switch event {
            case let .next(string):
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            case let .error(error):
                XCTFail("Unexpected error: \(error)")
            case .completed:
                shouldCallClosureCompleted.fulfill()
            }
        }.asSubscriber())

        wait(for: [shouldCallClosureValue, shouldCallClosureCompleted], timeout: 0.1)
    }

    func testObserverToSubscriberTypeOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let publisherType = PublisherType<String, Error> { subscriber in
            subscriber.onValue("test")
            subscriber.onCompleted(someError)
            return FooSubscription { }
        }

        _ = publisherType.subscribe(AnyObserver<String> { event in
            switch event {
            case let .next(string):
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            case let .error(error):
                XCTAssertEqual(someError, error as! SomeError)
                shouldCallClosureError.fulfill()
            case .completed:
                XCTFail("Unexpected completion")
            }
        }.asSubscriber())

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }

    #if !SWIFT_PACKAGE
    func testSubscriberTypeToObservableThrowingUnexpectedType() {
        struct OtherError: Error { }

        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let someError = SomeError()

        let observable = Observable<String>.create { observer in
            observer.onNext("test")
            expect { observer.onError(someError) }.to(throwAssertion())
            return Disposables.create()
        }

        _ = observable.subscribe(
            SubscriberType<String, OtherError>(
                onValue: { string in
                    XCTAssertEqual("test", string)
                    shouldCallClosureValue.fulfill()
                },
                onCompleted: { error in
                    XCTFail("Unexpected completion. Error? \(String(describing: error))")
                }
            ).asObserver()
        )

        wait(for: [shouldCallClosureValue], timeout: 0.1)
    }
    #endif
}
