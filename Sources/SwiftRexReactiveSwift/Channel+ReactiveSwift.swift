@preconcurrency import ReactiveSwift
import SwiftRex

private struct Unchecked<T>: @unchecked Sendable { let value: T }

// MARK: - SignalProducer → Channel (state-driven, long-lived subscriptions)
//
// The `asChannel` counterpart of `asEffect`: a `supervise` keeps the ``Channel`` alive, which `start`s
// the producer once (scoped to a `Lifetime`), dispatches each value as an action, and disposes the
// `Lifetime` when the channel leaves the desired set.
//
// ## Timing — synchronous emission is safe
//
// A producer can deliver values synchronously on `start` (a `Property`'s producer replays the current
// value), inside the channel body before the engine registers the channel. That is safe: every action a
// channel dispatches hops through the Store's `send` (`Task { @MainActor }`) onto a later turn, so a
// value delivered during start is captured and deferred — it cannot re-enter the in-flight reconcile, be
// lost, or double-open. The channel is a pure receiver (`cancelOnly`); for the *send* direction use
// `Effect.broadcast(_:channel:)`.

extension SignalProducer where Error == Never {
    /// Bridges a `SignalProducer<Action, Never>` to a long-lived ``Channel`` keyed by `id`.
    public func asChannel(
        id: some Hashable & Sendable,
        lifetime: Channel<Value>.Lifetime = .permanent
    ) -> Channel<Value> where Value: Sendable {
        let p = Unchecked(value: self)
        return Channel(id: id, lifetime: lifetime) { dispatch in
            let (producerLifetime, token) = Lifetime.make()
            p.value.take(during: producerLifetime).startWithValues { dispatch($0) }
            return .cancelOnly { token.dispose() }
        }
    }

    /// Bridges a `SignalProducer<Value, Never>` to a ``Channel`` by mapping each value to an action.
    public func asChannel<Action: Sendable>(
        id: some Hashable & Sendable,
        lifetime: Channel<Action>.Lifetime = .permanent,
        _ transform: @escaping @Sendable (Value) -> Action
    ) -> Channel<Action> {
        let p = Unchecked(value: self)
        return Channel(id: id, lifetime: lifetime) { dispatch in
            let (producerLifetime, token) = Lifetime.make()
            p.value.take(during: producerLifetime).startWithValues { dispatch(transform($0)) }
            return .cancelOnly { token.dispose() }
        }
    }
}

extension SignalProducer where Error: Swift.Error {
    /// Bridges a failable `SignalProducer<Value, Error>` to a ``Channel`` via a `Result` transform —
    /// each value is `.success`; a terminating error is `.failure`, then the producer is done.
    public func asChannel<Action: Sendable>(
        id: some Hashable & Sendable,
        lifetime: Channel<Action>.Lifetime = .permanent,
        _ transform: @escaping @Sendable (Result<Value, Error>) -> Action
    ) -> Channel<Action> {
        let p = Unchecked(value: self)
        return Channel(id: id, lifetime: lifetime) { dispatch in
            let (producerLifetime, token) = Lifetime.make()
            p.value
                .map { Result<Value, Error>.success($0) }
                .flatMapError { SignalProducer<Result<Value, Error>, Never>(value: .failure($0)) }
                .take(during: producerLifetime)
                .startWithValues { dispatch(transform($0)) }
            return .cancelOnly { token.dispose() }
        }
    }
}
