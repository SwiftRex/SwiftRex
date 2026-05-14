@preconcurrency import RxSwift
import SwiftRex

// MARK: - Store observation as Observable

extension StoreType {
    /// A cold `Observable<State>` that emits the current state after every mutation.
    /// Subscribes lazily — observation only begins when the Observable is subscribed to.
    public var observable: Observable<State> {
        Observable.create { [self] observer in
            let token = self.observe(didChange: { @MainActor [self] in
                observer.onNext(self.state)
            })
            return Disposables.create { token.cancel() }
        }
    }
}
