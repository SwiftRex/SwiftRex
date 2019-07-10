import Foundation
import RxSwift
import SwiftRex

extension Subscription {
    public func asDisposable() -> Disposable {
        if let disposable = self as? Disposable { return disposable }
        return DisposableSubscription(subscription: self)
    }
}

extension Disposable {
    public func asSubscription() -> Subscription {
        if let subscription = self as? Subscription { return subscription }
        return DisposableSubscription(disposable: self)
    }
}

private class DisposableSubscription: Disposable, Subscription {
    let disposable: Disposable

    init(disposable: Disposable) {
        self.disposable = disposable
    }

    init(subscription: Subscription) {
        self.disposable = Disposables.create {
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

extension DisposeBag: SubscriptionCollection {
    public func append(subscription: Subscription) {
        let disposable = subscription.asDisposable()
        disposable.disposed(by: self)
    }
}
