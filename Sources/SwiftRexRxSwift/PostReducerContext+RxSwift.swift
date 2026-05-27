@preconcurrency import RxSwift
import SwiftRex

extension PostReducerContext {
    /// Returns a single-element observable that reads the post-mutation state on the main actor.
    ///
    /// The state is read lazily — only when a subscriber subscribes, not when the observable
    /// is constructed. This ensures the state read always reflects the Store's state at the
    /// moment of subscription, which inside a `produce` closure is post-mutation state.
    ///
    /// ```swift
    /// Behavior<MyAction, MyState, API>.handle { action, _ in
    ///     guard case .save(let data) = action else { return .doNothing }
    ///     return .produce { ctx in
    ///         ctx.readStateAfter()
    ///             .flatMap { state in ctx.environment.api.save(data, revision: state.revision) }
    ///             .asEffect()
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: An `Observable<State>` that emits the post-mutation state once and completes.
    ///   Emits nothing if the Store has been deallocated.
    public func readStateAfter() -> Observable<State> {
        Observable.create { observer in
            Task { @MainActor [self] in
                if let s = self.stateAfter {
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
