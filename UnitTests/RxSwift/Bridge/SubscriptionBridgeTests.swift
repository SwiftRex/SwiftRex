import RxSwift
import RxSwiftRex
import SwiftRex
import XCTest

class SubscriptionBridgeTests: XCTestCase {
    struct FooSubscription: Subscription {
        let onUnsubscribe: () -> Void
        func unsubscribe() { onUnsubscribe() }
    }

    func testDisposableSubscriptionInitFromDisposableDispose() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let disposable = Disposables.create {
            shouldBeDisposed.fulfill()
        }

        let sut = DisposableSubscription(disposable: disposable)
        sut.dispose()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testDisposableSubscriptionInitFromDisposableUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let disposable = Disposables.create {
            shouldBeDisposed.fulfill()
        }

        let sut = DisposableSubscription(disposable: disposable)
        sut.unsubscribe()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testDisposableSubscriptionInitFromSubscriptionDispose() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = DisposableSubscription(subscription: subscription)
        sut.dispose()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testDisposableSubscriptionInitFromSubscriptionUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = DisposableSubscription(subscription: subscription)
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

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testSubscriptionToDisposableUnsubscribe() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }

        let sut = subscription.asDisposable()
        sut.unsubscribe()

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }

    func testSubscriptionDisposedByDisposeBag() {
        let shouldBeDisposed = expectation(description: "should be disposed")
        let subscription = FooSubscription {
            shouldBeDisposed.fulfill()
        }
        var disposeBag: DisposeBag? = .init()

        subscription.disposed(by: disposeBag!)
        disposeBag = nil

        wait(for: [shouldBeDisposed], timeout: 0.1)
    }
}
