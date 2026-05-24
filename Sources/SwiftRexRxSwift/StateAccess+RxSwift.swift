@preconcurrency import RxSwift
import SwiftRex

extension StateAccess {
    /// Returns a single-element observable that reads the current state on the main actor.
    ///
    /// The state is read lazily — only when a subscriber subscribes, not when the observable
    /// is constructed. This preserves the three-phase timing contract: the state you receive
    /// reflects the Store's state at the moment of subscription, which inside a `Reader` closure
    /// is post-mutation state.
    ///
    /// ```swift
    /// Middleware<MyAction, MyState, MyEnvironment>.handle { _, stateAccess in
    ///     Reader { env in
    ///         stateAccess.readState()
    ///             .flatMap { currentState in env.api.fetch(currentState.query) }
    ///             .asEffect()
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: An `Observable<State>` that emits the current state once and completes.
    ///   Emits nothing if the Store has been deallocated.
    public func readState() -> Observable<State> {
        Observable.create { observer in
            Task { @MainActor [self] in
                if let s = self.state {
                    observer.onNext(s)
                    observer.onCompleted()
                } else {
                    observer.onCompleted()
                }
            }
            return Disposables.create()
        }
    }
}
