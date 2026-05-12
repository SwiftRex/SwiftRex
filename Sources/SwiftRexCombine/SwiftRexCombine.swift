@preconcurrency import Combine
import SwiftRex

// Wraps reactive types that haven't been annotated for Swift 6 Sendable yet.
private struct Unchecked<T>: @unchecked Sendable { let value: T }

// MARK: - Publisher → Effect bridges
//
//   Case A  Publisher<Action, Never>          .asEffect()    — output is already Action
//   Case B  Publisher<Output, Never>          .asEffect(fn)  — infallible, map Output→Action
//   Case C  Publisher<Output, Failure: Error> .asEffect(fn)  — failable, map Result→Action
//
// Completion: `complete()` fires on `.finished` or after the error action (Case C).
// Cancellation via SubscriptionToken suppresses further Combine callbacks so `complete()` is
// never called after cancellation.

extension Publisher where Failure == Never {
    /// Bridges a `Publisher<Action, Never>` to `Effect<Action>`. No transform needed.
    public func asEffect(
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Output> where Output: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        let publisher = Unchecked(value: self)
        return Effect(components: [
            Effect<Output>.Component(subscribe: { send, complete in
                let c = publisher.value.sink(
                    receiveCompletion: { _ in complete() },
                    receiveValue: { send(DispatchedAction($0, dispatcher: source)) }
                )
                return SubscriptionToken { c.cancel() }
            }, scheduling: .immediately)
        ])
    }

    /// Bridges a `Publisher<Output, Never>` to `Effect<Action>` by mapping each value.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Output) -> Action,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let publisher = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let c = publisher.value.sink(
                    receiveCompletion: { _ in complete() },
                    receiveValue: { send(DispatchedAction(transform($0), dispatcher: source)) }
                )
                return SubscriptionToken { c.cancel() }
            }, scheduling: .immediately)
        ])
    }
}

extension Publisher where Failure: Error {
    /// Bridges a failable `Publisher<Output, Failure>` to `Effect<Action>` via Result.
    ///
    /// Each value arrives as `.success`; a failure arrives as `.failure` and is dispatched
    /// before `complete()` fires. Multiple values before an error are all delivered.
    ///
    /// ```swift
    /// apiPublisher.asEffect(AppAction.didFetch)
    /// // enum AppAction { case didFetch(Result<MyModel, DecodingError>) }
    /// ```
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Result<Output, Failure>) -> Action,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let publisher = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let c = publisher.value.sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            send(DispatchedAction(transform(.failure(error)), dispatcher: source))
                        }
                        complete()
                    },
                    receiveValue: { send(DispatchedAction(transform(.success($0)), dispatcher: source)) }
                )
                return SubscriptionToken { c.cancel() }
            }, scheduling: .immediately)
        ])
    }
}
