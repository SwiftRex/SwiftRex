@preconcurrency import RxSwift
import SwiftRex

extension PostReducerContext {
    /// Returns a single-element observable that reads the Store's current state on the main actor.
    ///
    /// The state is read lazily — only when a subscriber subscribes, not when the observable
    /// is constructed. The emitted value reflects the Store's state at the moment of
    /// subscription; subscribing synchronously inside a `produce` closure yields this cycle's
    /// post-mutation state, while a later subscription yields whatever the Store holds then.
    ///
    /// ```swift
    /// Behavior<MyAction, MyState, API>.handle { action, _ in
    ///     guard case .save(let data) = action else { return .doNothing }
    ///     return .produce { ctx in
    ///         ctx.readLiveState()
    ///             .flatMap { state in ctx.environment.api.save(data, revision: state.revision) }
    ///             .asEffect()
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: An `Observable<State>` that emits the current state once and completes.
    ///   Emits nothing if the Store has been deallocated.
    public func readLiveState() -> Observable<State> {
        Observable.create { observer in
            Task { @MainActor [self] in
                if let s = self.liveState {
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
