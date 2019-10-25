import Foundation
import RxSwift
import SwiftRex

extension SubscriptionType {
    public func asDisposable() -> Disposable {
        if let disposable = self as? Disposable { return disposable }
        return DisposableSubscription(subscription: self)
    }
}

extension Disposable {
    public func asSubscription() -> SubscriptionType {
        if let subscription = self as? SubscriptionType { return subscription }
        return DisposableSubscription(disposable: self)
    }
}

private class DisposableSubscription: Disposable, SubscriptionType {
    let disposable: Disposable

    init(disposable: Disposable) {
        self.disposable = disposable
    }

    init(subscription: SubscriptionType) {
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
    public func store(subscription: SubscriptionType) {
        let disposable = subscription.asDisposable()
        disposable.disposed(by: self)
    }
}
