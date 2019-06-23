import Foundation
import ReactiveSwift
import SwiftRex

extension Subscription {
    public func asDisposable() -> DisposableSubscription {
        return DisposableSubscription(subscription: self)
    }

    public func disposed(by disposeBag: inout Lifetime) {
        let disposable: Disposable = self.asDisposable()
        disposeBag += disposable
    }
}

public class DisposableSubscription: Disposable, Subscription {
    let disposable: Disposable
    public var isDisposed: Bool { return disposable.isDisposed }

    public init(disposable: Disposable) {
        self.disposable = disposable
    }

    public init(subscription: Subscription) {
        self.disposable = AnyDisposable {
            subscription.unsubscribe()
        }
    }

    public func unsubscribe() {
        disposable.dispose()
    }

    public func dispose() {
        disposable.dispose()
    }
}
