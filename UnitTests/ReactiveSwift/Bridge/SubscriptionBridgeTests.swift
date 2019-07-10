import ReactiveSwift
import ReactiveSwiftRex
import SwiftRex
import XCTest

class SubscriptionBridgeTests: XCTestCase {
    func testDisposableToSubscriptionUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")

        let disposable = AnyDisposable {
            shouldBeDisposed.fulfill()
        }

        let sut = disposable.asSubscription()
        sut.unsubscribe()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testSubscriptionToDisposableDispose() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = subscription.asDisposable()
        sut.dispose()

        XCTAssertTrue(sut.isDisposed)
        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testDisposableToSubscriptionToDisposableDispose() {
        let shouldBeDisposed = expectation(description: "should be disposed")

        let disposable = AnyDisposable {
            shouldBeDisposed.fulfill()
        }

        let sut = disposable.asSubscription().asDisposable()
        sut.dispose()

        XCTAssertTrue(sut.isDisposed)
        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testSubscriptionToDisposableToSubscriptionUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = subscription.asDisposable().asSubscription()
        sut.unsubscribe()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testSubscriptionCollectionAppend() {
        let shouldBeDisposed = expectation(description: "should be disposed")

        let disposable = AnyDisposable {
            shouldBeDisposed.fulfill()
        }

        let subscription = disposable.asSubscription()
        var (sut, _): (Lifetime?, Lifetime.Token) = Lifetime.make()
        subscription.cancelled(by: &sut!)

        sut = nil

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }
}
