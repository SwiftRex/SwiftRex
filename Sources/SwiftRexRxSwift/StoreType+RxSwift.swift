@preconcurrency import RxSwift
import SwiftRex

// MARK: - Store observation as Observable

extension StoreType {
    /// A cold `Observable<State>` that emits the current state after every mutation.
    ///
    /// Subscribes lazily — ``StoreType/observe(willChange:didChange:)`` is only called when an
    /// RxSwift subscriber attaches via `subscribe`. Each subscription creates an independent
    /// ``SubscriptionToken``; disposing the `Disposable` cancels the token and removes the
    /// observer from the store.
    ///
    /// Each emission reads ``StoreType/state`` once immediately after the mutation on the
    /// `@MainActor`. Use `.observe(on:)` to hop to a different scheduler if needed.
    ///
    /// ```swift
    /// store.observable
    ///     .map(\.username)
    ///     .distinctUntilChanged()
    ///     .observe(on: MainScheduler.instance)
    ///     .subscribe(onNext: { [weak self] name in self?.nameLabel.text = name })
    ///     .disposed(by: disposeBag)
    /// ```
    ///
    /// To create an ``Effect`` from this observable, use one of the ``ObservableType/asEffect``
    /// overloads provided by `SwiftRexRxSwift`.
    public var observable: Observable<State> {
        Observable.create { [self] observer in
            let token = self.observe(didChange: { @MainActor [self] in
                observer.onNext(self.state)
            })
            return Disposables.create { token.cancel() }
        }
    }
}
