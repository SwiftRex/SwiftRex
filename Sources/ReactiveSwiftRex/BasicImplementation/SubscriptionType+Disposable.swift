import Foundation
import ReactiveSwift
import SwiftRex

extension SubscriptionType {
    public func asDisposable() -> Disposable {
        if let disposable = self as? Disposable { return disposable }
        return DisposableSubscription(subscription: self)
    }
}

extension Disposable {
    public func asSubscriptionType() -> SubscriptionType {
        if let subscription = self as? SubscriptionType { return subscription }
        return DisposableSubscription(disposable: self)
    }
}

private class DisposableSubscription: Disposable, SubscriptionType {
    let disposable: Disposable
    var isDisposed: Bool { disposable.isDisposed }

    init(disposable: Disposable) {
        self.disposable = disposable
    }

    init(subscription: SubscriptionType) {
        self.disposable = AnyDisposable {
            subscription.unsubscribe()
        }
    }

    func unsubscribe() {
        disposable.dispose()
    }

    func dispose() {
        disposable.dispose()
    }
}

extension Lifetime: SubscriptionCollection {
    public func store(subscription: SubscriptionType) {
        let disposable = subscription.asDisposable()
        self += disposable
    }
}
