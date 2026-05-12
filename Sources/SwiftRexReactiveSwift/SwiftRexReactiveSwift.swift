@preconcurrency import ReactiveSwift
import SwiftRex

private struct Unchecked<T>: @unchecked Sendable { let value: T }

// MARK: - SignalProducer / Signal → Effect bridges
//
// ReactiveSwift distinguishes at the type level: Error == Never → infallible.
//
//   Case A  SignalProducer<Action, Never>  .asEffect()    — value is already Action
//   Case B  SignalProducer<V, Never>       .asEffect(fn)  — map Value→Action
//   Case C  SignalProducer<V, E: Error>    .asEffect(fn)  — map Result<V,E>→Action
//
// Signal<Value, Error> (hot) delegates to SignalProducer for the same three cases.
//
// Completion: `complete()` fires on `.completed` or after the error action (Case C).
// Cancellation via SubscriptionToken disposes the Lifetime; ReactiveSwift suppresses further
// events on disposal so `complete()` is never called after cancellation.

// MARK: - SignalProducer (cold)

extension SignalProducer where Error == Never {
    /// Bridges a `SignalProducer<Action, Never>` to `Effect<Action>`.
    public func asEffect(
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Value> where Value: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        let producer = Unchecked(value: self)
        return Effect(components: [
            Effect<Value>.Component(subscribe: { send, complete in
                let (lifetime, token) = Lifetime.make()
                producer.value.take(during: lifetime).startWithSignal { signal, _ in
                    signal.observeValues { send(DispatchedAction($0, dispatcher: source)) }
                    signal.observeCompleted { complete() }
                }
                return SubscriptionToken { token.dispose() }
            }, scheduling: .immediately)
        ])
    }

    /// Bridges a `SignalProducer<Value, Never>` to `Effect<Action>` by mapping each value.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Value) -> Action,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let producer = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let (lifetime, token) = Lifetime.make()
                producer.value.take(during: lifetime).startWithSignal { signal, _ in
                    signal.observeValues { send(DispatchedAction(transform($0), dispatcher: source)) }
                    signal.observeCompleted { complete() }
                }
                return SubscriptionToken { token.dispose() }
            }, scheduling: .immediately)
        ])
    }
}

extension SignalProducer where Error: Swift.Error {
    /// Bridges a failable `SignalProducer<Value, Error>` to `Effect<Action>` via Result.
    ///
    /// Each value arrives as `.success`; a failure arrives as `.failure` and is dispatched
    /// before `complete()` fires.
    ///
    /// ```swift
    /// apiProducer.asEffect(AppAction.didFetch)
    /// // enum AppAction { case didFetch(Result<MyModel, MyError>) }
    /// ```
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Result<Value, Error>) -> Action,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let producer = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let (lifetime, token) = Lifetime.make()
                producer.value
                    .map { Result<Value, Error>.success($0) }
                    .flatMapError { SignalProducer<Result<Value, Error>, Never>(value: .failure($0)) }
                    .take(during: lifetime)
                    .startWithSignal { signal, _ in
                        signal.observeValues { send(DispatchedAction(transform($0), dispatcher: source)) }
                        signal.observeCompleted { complete() }
                    }
                return SubscriptionToken { token.dispose() }
            }, scheduling: .immediately)
        ])
    }
}

// MARK: - Signal (hot) — delegates to SignalProducer

extension Signal where Error == Never {
    public func asEffect(
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Value> where Value: Sendable {
        SignalProducer(self).asEffect(file: file, function: function, line: line)
    }

    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Value) -> Action,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        SignalProducer(self).asEffect(transform, file: file, function: function, line: line)
    }
}

extension Signal where Error: Swift.Error {
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Result<Value, Error>) -> Action,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        SignalProducer(self).asEffect(transform, file: file, function: function, line: line)
    }
}
