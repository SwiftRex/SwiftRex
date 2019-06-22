import Foundation
import RxSwift
import SwiftRex

extension SwiftRex.Subscription {
    public func asDisposable() -> DisposableSubscription {
        return DisposableSubscription(subscription: self)
    }

    public func disposed(by disposeBag: DisposeBag) {
        let disposable: Disposable = self.asDisposable()
        disposable.disposed(by: disposeBag)
    }
}

public class DisposableSubscription: Disposable, SwiftRex.Subscription {
    let disposable: Disposable

    public init(disposable: Disposable) {
        self.disposable = disposable
    }

    public init(subscription: SwiftRex.Subscription) {
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
