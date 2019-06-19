import Foundation
import RxSwift
import SwiftRex

extension Subscription {
    public func asDisposable() -> DisposableSubscription {
        return DisposableSubscription(subscription: self)
    }

    public func disposed(by disposeBag: DisposeBag) {
        let disposable: Disposable = self.asDisposable()
        disposable.disposed(by: disposeBag)
    }
}

public struct DisposableSubscription: Disposable, Subscription {
    let disposable: Disposable

    public init(disposable: Disposable) {
        self.disposable = disposable
    }

    public init(subscription: Subscription) {
        self.disposable = Disposables.create {
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
