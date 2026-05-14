@preconcurrency import ReactiveSwift
import SwiftRex

private struct Unchecked<T>: @unchecked Sendable { let value: T }

// MARK: - SignalProducer (cold)
//
//   Case A   SignalProducer<Action, Never>               .asEffect(scheduling:)
//   Case A2  SignalProducer<DispatchedAction<A>, Never>  .asEffect(scheduling:)  — forwarding
//   Case B   SignalProducer<V, Never>                    .asEffect(_ transform:scheduling:)
//   Case C   SignalProducer<V, E: Error>                 .asEffect(_ transform:scheduling:)
//
// Signal<Value, Error> (hot) delegates to SignalProducer.

extension SignalProducer where Error == Never {
    /// Bridges a `SignalProducer<Action, Never>` to `Effect<Action>`.
    public func asEffect(
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Value> where Value: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Value>.Component(subscribe: { send, complete in
                let (lifetime, token) = Lifetime.make()
                p.value.take(during: lifetime).startWithSignal { signal, _ in
                    signal.observeValues { send(DispatchedAction($0, dispatcher: source)) }
                    signal.observeCompleted { complete() }
                }
                return SubscriptionToken { token.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges a `SignalProducer<DispatchedAction<Action>, Never>`, forwarding dispatchers.
    public func asEffect<Action: Sendable>(
        scheduling: EffectScheduling = .immediately
    ) -> Effect<Action> where Value == DispatchedAction<Action> {
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let (lifetime, token) = Lifetime.make()
                p.value.take(during: lifetime).startWithSignal { signal, _ in
                    signal.observeValues { send($0) }
                    signal.observeCompleted { complete() }
                }
                return SubscriptionToken { token.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges a `SignalProducer<Value, Never>` to `Effect<Action>` by mapping each value.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Value) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let (lifetime, token) = Lifetime.make()
                p.value.take(during: lifetime).startWithSignal { signal, _ in
                    signal.observeValues { send(DispatchedAction(transform($0), dispatcher: source)) }
                    signal.observeCompleted { complete() }
                }
                return SubscriptionToken { token.dispose() }
            }, scheduling: scheduling)
        ])
    }
}

extension SignalProducer where Error: Swift.Error {
    /// Bridges a failable `SignalProducer<Value, Error>` to `Effect<Action>` via Result.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Result<Value, Error>) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let (lifetime, token) = Lifetime.make()
                p.value
                    .map { Result<Value, Error>.success($0) }
                    .flatMapError { SignalProducer<Result<Value, Error>, Never>(value: .failure($0)) }
                    .take(during: lifetime)
                    .startWithSignal { signal, _ in
                        signal.observeValues { send(DispatchedAction(transform($0), dispatcher: source)) }
                        signal.observeCompleted { complete() }
                    }
                return SubscriptionToken { token.dispose() }
            }, scheduling: scheduling)
        ])
    }
}

// MARK: - Signal (hot) — delegates to SignalProducer

extension Signal where Error == Never {
    public func asEffect(
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Value> where Value: Sendable {
        SignalProducer(self).asEffect(scheduling: scheduling, file: file, function: function, line: line)
    }

    public func asEffect<Action: Sendable>(
        scheduling: EffectScheduling = .immediately
    ) -> Effect<Action> where Value == DispatchedAction<Action> {
        SignalProducer(self).asEffect(scheduling: scheduling)
    }

    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Value) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Action> {
        SignalProducer(self).asEffect(transform, scheduling: scheduling, file: file, function: function, line: line)
    }
}

extension Signal where Error: Swift.Error {
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Result<Value, Error>) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Action> {
        SignalProducer(self).asEffect(transform, scheduling: scheduling, file: file, function: function, line: line)
    }
}

// MARK: - Fire and forget (ReactiveSwift)

extension Effect {
    /// Subscribes to a `SignalProducer`, ignoring all values and errors, completing when done.
    /// Use with `|>`: `myProducer |> Effect.fireAndForget`.
    public static func fireAndForget<V, E: Swift.Error>(_ sp: SignalProducer<V, E>) -> Self {
        let sp = Unchecked(value: sp)
        return Effect(components: [
            Component(subscribe: { _, complete in
                let (lifetime, token) = Lifetime.make()
                sp.value.take(during: lifetime).startWithSignal { signal, _ in
                    signal.observeCompleted { complete() }
                    signal.observeFailed { _ in complete() }
                }
                return SubscriptionToken { token.dispose() }
            }, scheduling: .immediately)
        ])
    }

    /// Subscribes to a hot `Signal`, ignoring all values and errors, completing when done.
    /// Use with `|>`: `mySignal |> Effect.fireAndForget`.
    public static func fireAndForget<V, E: Swift.Error>(_ signal: Signal<V, E>) -> Self {
        fireAndForget(SignalProducer(signal))
    }
}
