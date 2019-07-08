import Combine
import CombineRex
import SwiftRex
import XCTest

class SubscriptionBridgeTests: XCTestCase {
    func testCancellableSubscriptionInitFromCancellableCancel() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let cancellable = AnyCancellable {
            shouldBeDisposed.fulfill()
        }

        let sut = CancellableSubscription(cancellable: cancellable)
        sut.cancel()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testCancellableSubscriptionInitFromCancellableUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let cancellable = AnyCancellable {
            shouldBeDisposed.fulfill()
        }

        let sut = CancellableSubscription(cancellable: cancellable)
        sut.unsubscribe()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testCancellableSubscriptionInitFromSubscriptionCancel() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = CancellableSubscription(subscription: subscription)
        sut.cancel()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testCancellableSubscriptionInitFromSubscriptionUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = CancellableSubscription(subscription: subscription)
        sut.unsubscribe()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testSubscriptionToCancellableCancel() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = subscription.asCancellable()
        sut.cancel()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testSubscriptionToCancellableUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = subscription.asCancellable()
        sut.unsubscribe()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testCancellableSubscriptionInitFromCombineSubscriptionCancel() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let combineSubscription = FooCombineSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = CancellableSubscription(combineSubscription: combineSubscription)
        sut.cancel()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testCancellableSubscriptionInitFromCombineSubscriptionUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let combineSubscription = FooCombineSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = CancellableSubscription(combineSubscription: combineSubscription)
        sut.request(.none)
        sut.unsubscribe()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }
}
