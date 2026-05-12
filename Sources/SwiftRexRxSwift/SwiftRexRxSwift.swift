@preconcurrency import RxSwift
import SwiftRex

private struct Unchecked<T>: @unchecked Sendable { let value: T }

// MARK: - ObservableType → Effect bridges
//
// RxSwift has no type-level Never/Error distinction — all observables can fail.
//
//   Case A  Observable<Action>   .asEffect()    — element is already Action; errors discarded
//   Case B  Observable<Output>   .asEffect(fn)  — map Output→Action; errors discarded
//   Case C  Observable<Output>   .asEffect(fn)  — map Result<Output, Error>→Action
//
// Completion: `complete()` fires on `.onCompleted` or after the error action (Case C).
// Cancellation via SubscriptionToken disposes the subscription; disposed observers receive
// no further events so `complete()` is never called after cancellation.

// MARK: - Infallible (RxSwift 6+)
//
// `Infallible<Element>` cannot error — it is the RxSwift equivalent of `Publisher<E, Never>`.
// No Result wrapping is needed; the two cases mirror the Combine infallible bridge.

extension InfallibleType {
    /// Bridges an `Infallible<Action>` to `Effect<Action>`. No transform needed.
    public func asEffect(
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Element> where Element: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        let infallible = Unchecked(value: self)
        return Effect(components: [
            Effect<Element>.Component(subscribe: { send, complete in
                let d = infallible.value.subscribe(
                    onNext:      { send(DispatchedAction($0, dispatcher: source)) },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: .immediately)
        ])
    }

    /// Bridges an `Infallible<Output>` to `Effect<Action>` by mapping each element.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Element) -> Action,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let infallible = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let d = infallible.value.subscribe(
                    onNext:      { send(DispatchedAction(transform($0), dispatcher: source)) },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: .immediately)
        ])
    }
}

// MARK: - Observable (failable)

extension ObservableType {
    /// Bridges an `Observable<Action>` to `Effect<Action>`. Errors are silently discarded.
    public func asEffect(
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Element> where Element: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        let observable = Unchecked(value: self)
        return Effect(components: [
            Effect<Element>.Component(subscribe: { send, complete in
                let d = observable.value.subscribe(
                    onNext:      { send(DispatchedAction($0, dispatcher: source)) },
                    onError:     { _ in complete() },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: .immediately)
        ])
    }

    /// Bridges an `Observable<Output>` to `Effect<Action>` by mapping each element.
    /// Errors are silently discarded.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Element) -> Action,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let observable = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let d = observable.value.subscribe(
                    onNext:      { send(DispatchedAction(transform($0), dispatcher: source)) },
                    onError:     { _ in complete() },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: .immediately)
        ])
    }

    /// Bridges an `Observable<Output>` to `Effect<Action>` via a Result transform.
    ///
    /// Each element arrives as `.success`; an error arrives as `.failure` and is dispatched
    /// before `complete()` fires.
    ///
    /// ```swift
    /// apiObservable.asEffect(AppAction.didFetch)
    /// // enum AppAction { case didFetch(Result<MyModel, Error>) }
    /// ```
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Result<Element, Error>) -> Action,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let observable = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let d = observable.value.subscribe(
                    onNext:      { send(DispatchedAction(transform(.success($0)), dispatcher: source)) },
                    onError:     { error in
                        send(DispatchedAction(transform(.failure(error)), dispatcher: source))
                        complete()
                    },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: .immediately)
        ])
    }
}
