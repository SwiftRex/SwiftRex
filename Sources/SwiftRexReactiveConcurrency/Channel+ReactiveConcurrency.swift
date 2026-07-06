// SPDX-License-Identifier: Apache-2.0

import ReactiveConcurrency
import SwiftRex

// MARK: - Publisher → Channel (state-driven, long-lived subscriptions)

//
// The `asChannel` counterpart of `asEffect` for the ReactiveConcurrency `Publisher` (Combine's surface
// over `AsyncSequence`): a `supervise` keeps the ``Channel`` alive, which `sink`s the publisher once,
// dispatches each value as an action, and `cancel`s the subscription when the channel leaves the
// desired set.
//
// ## Timing — synchronous emission is safe
//
// A replayed/current-value publisher may emit synchronously on `sink`, inside the channel body before
// the engine registers the channel. That is safe: every action a channel dispatches hops through the
// Store's `send` (`Task { @MainActor }`) onto a later turn, so a value emitted during subscription is
// captured and deferred — it cannot re-enter the in-flight reconcile, be lost, or double-open. The
// channel is a pure receiver (`cancelOnly`); for the *send* direction use `Effect.broadcast(_:channel:)`.

extension Publisher where Failure == Never {
    /// Bridges a `Publisher<Action, Never>` to a long-lived ``Channel`` keyed by `id`.
    public func asChannel(
        id: some Hashable & Sendable,
        lifetime: Channel<Output>.Lifetime = .permanent
    ) -> Channel<Output> where Output: Sendable {
        Channel(id: id, lifetime: lifetime) { dispatch in
            let c = self.sink(receiveValue: { dispatch($0) })
            return .cancelOnly { c.cancel() }
        }
    }

    /// Bridges a `Publisher<Output, Never>` to a ``Channel`` by mapping each value to an action.
    public func asChannel<Action: Sendable>(
        id: some Hashable & Sendable,
        lifetime: Channel<Action>.Lifetime = .permanent,
        _ transform: @escaping @Sendable (Output) -> Action
    ) -> Channel<Action> {
        Channel(id: id, lifetime: lifetime) { dispatch in
            let c = self.sink(receiveValue: { dispatch(transform($0)) })
            return .cancelOnly { c.cancel() }
        }
    }
}

extension Publisher where Failure: Error {
    /// Bridges a failable `Publisher<Output, Failure>` to a ``Channel`` via a `Result` transform —
    /// each value is `.success`; a terminating error is `.failure`, then the publisher is done.
    public func asChannel<Action: Sendable>(
        id: some Hashable & Sendable,
        lifetime: Channel<Action>.Lifetime = .permanent,
        _ transform: @escaping @Sendable (Result<Output, Failure>) -> Action
    ) -> Channel<Action> {
        Channel(id: id, lifetime: lifetime) { dispatch in
            let c = self.sink(
                receiveCompletion: { if case let .failure(error) = $0 { dispatch(transform(.failure(error))) } },
                receiveValue: { dispatch(transform(.success($0))) }
            )
            return .cancelOnly { c.cancel() }
        }
    }
}
