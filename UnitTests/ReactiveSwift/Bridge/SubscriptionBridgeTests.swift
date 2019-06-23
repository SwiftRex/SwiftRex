import ReactiveSwift
import SwiftRex
import SwiftRexForRac
import XCTest

class SubscriptionBridgeTests: XCTestCase {
    struct FooSubscription: Subscription {
        let onUnsubscribe: () -> Void
        func unsubscribe() { onUnsubscribe() }
    }

    func testDisposableSubscriptionInitFromDisposableDispose() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let disposable = AnyDisposable {
            shouldBeDisposed.fulfill()
        }

        let sut = DisposableSubscription(disposable: disposable)
        sut.dispose()
        XCTAssertTrue(sut.isDisposed)

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testDisposableSubscriptionInitFromDisposableUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let disposable = AnyDisposable {
            shouldBeDisposed.fulfill()
        }

        let sut = DisposableSubscription(disposable: disposable)
        sut.unsubscribe()
        XCTAssertTrue(sut.isDisposed)

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testDisposableSubscriptionInitFromSubscriptionDispose() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = DisposableSubscription(subscription: subscription)
        sut.dispose()
        XCTAssertTrue(sut.isDisposed)

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testDisposableSubscriptionInitFromSubscriptionUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = DisposableSubscription(subscription: subscription)
        sut.unsubscribe()
        XCTAssertTrue(sut.isDisposed)

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

    func testSubscriptionToDisposableUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = subscription.asDisposable()
        sut.unsubscribe()
        XCTAssertTrue(sut.isDisposed)

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testSubscriptionDisposedByDisposeBag() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }
        var (lifetime, token): (Lifetime, Lifetime.Token?) = Lifetime.make()

        subscription.disposed(by: lifetime)

        XCTAssertNotNil(token)
        token = nil
        XCTAssertTrue(lifetime.hasEnded)

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }
}
