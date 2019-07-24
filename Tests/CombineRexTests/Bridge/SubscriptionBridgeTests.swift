import Combine
import CombineRex
import SwiftRex
import XCTest

class SubscriptionBridgeTests: XCTestCase {
    func testCancellableToSubscriptionUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")

        let cancellable = AnyCancellable {
            shouldBeDisposed.fulfill()
        }

        let sut = cancellable.asSubscription()
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

    func testCancellableToSubscriptionToCancellableCancel() {
        let shouldBeDisposed = expectation(description: "should be disposed")

        let cancellable = AnyCancellable {
            shouldBeDisposed.fulfill()
        }

        let sut = cancellable.asSubscription().asCancellable()
        sut.cancel()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testSubscriptionToCancellableToSubscriptionUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = subscription.asCancellable().asSubscription()
        sut.unsubscribe()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testSubscriptionToCancellableRequestIgnoredWhenNotCombineSubscription() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription(onUnsubscribe: {
            shouldBeDisposed.fulfill()
        })

        let sut = subscription.asCancellable()
        sut.request(.unlimited)
        sut.cancel()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testSubscriptionToCancellableRequest() {
        let shouldBeRequested = expectation(description: "should be requested")
        var fooCombineSubscription = FooCombineSubscription { }
        fooCombineSubscription.onRequest = { demand in
            XCTAssertEqual(.unlimited, demand)
            shouldBeRequested.fulfill()
        }
        let subscription = fooCombineSubscription.asSubscription()

        let sut = subscription.asCancellable()
        sut.request(.unlimited)

        wait(for: [shouldBeRequested], timeout: 0.1)
    }

    func testSubscriptionCollectionAppend() {
        let shouldBeDisposed = expectation(description: "should be disposed")

        let cancellable = AnyCancellable {
            shouldBeDisposed.fulfill()
        }

        let subscription = cancellable.asSubscription()
        var sut: [AnyCancellable]? = [AnyCancellable]() // swiftlint:disable:this discouraged_optional_collection
        subscription.cancelled(by: &sut!)

        sut = nil

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }
}
