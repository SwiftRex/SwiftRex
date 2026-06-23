#if canImport(Combine)
@preconcurrency import Combine
import SwiftRex

private struct Unchecked<T>: @unchecked Sendable { let value: T }

// MARK: - Publisher → Channel bridges (state-driven, long-lived subscriptions)
//
// Where `asEffect` turns a publisher into a one-shot `Effect` (recreated on each dispatch), `asChannel`
// turns it into a long-lived ``Channel`` — the unit a `supervise` keeps alive. Declare it from state
// and the Store opens the subscription once, dispatches each element as an action, and cancels the
// `AnyCancellable` when the channel leaves the desired set. You never write the teardown.
//
//     .supervise { state in
//         Keep { env in
//             guard state.isTracking else { return [] }
//             return [env.locationPublisher.asChannel(id: "location", AppAction.located)]
//         }
//     }
//
// ## Timing — synchronous emission is safe
//
// A publisher may emit **synchronously on subscription** (`Just`, `CurrentValueSubject`, a replayed
// subject). That emission happens *inside* the channel body, while the engine is still mid-reconcile
// and before it has registered the channel. This is safe: every action a channel dispatches is routed
// through the Store's `send`, which hops via `Task { @MainActor }` to a **later** run-loop turn. So a
// value emitted during subscription is captured and *deferred* — it cannot re-enter the in-flight
// reconcile, cannot be lost, and cannot cause a double-open. By the time the deferred action is
// processed, the channel is fully registered, and (if the action mutates state) the follow-up reconcile
// sees an unchanged desired set and does nothing. The subscription's `AnyCancellable` is likewise only
// captured into the teardown closure, never referenced from the value handler, so an emission that fires
// before `sink` returns is still correct.
//
// The channel is a *pure receiver*: a plain `Publisher` is output-only, so its ``ChannelHandler`` is
// `cancelOnly` (nothing is ever piped in). For the *send* direction use `Effect.broadcast(_:channel:)`.

extension Publisher where Failure == Never {
    /// Bridges a `Publisher<Action, Never>` to a long-lived ``Channel`` keyed by `id`.
    ///
    /// The call-site is captured as the ``ActionSource`` for every element. Use this overload when the
    /// publisher's `Output` is already the action type.
    ///
    /// - Parameters:
    ///   - id: The channel key — the registry slot the subscription occupies (and the id an
    ///     `Effect.broadcast(_:channel:)` could target, though a plain publisher only emits *out*).
    ///   - lifetime: ``Channel/Lifetime`` — `.permanent` (default) keeps the subscription across state
    ///     changes; `.ephemeral(resetKey:)` resubscribes whenever the key changes.
    /// - Returns: A ``Channel`` that subscribes on open and cancels on teardown.
    public func asChannel(
        id: some Hashable & Sendable,
        lifetime: Channel<Output>.Lifetime = .permanent
    ) -> Channel<Output> where Output: Sendable {
        let p = Unchecked(value: self)
        return Channel(id: id, lifetime: lifetime) { dispatch in
            let c = p.value.sink(receiveValue: { dispatch($0) })
            return .cancelOnly { c.cancel() }
        }
    }

    /// Bridges a `Publisher<Output, Never>` to a ``Channel`` by mapping each value to an action.
    ///
    /// - Parameters:
    ///   - id: The channel key.
    ///   - lifetime: ``Channel/Lifetime`` (default `.permanent`).
    ///   - transform: Maps each emitted `Output` to an `Action`.
    public func asChannel<Action: Sendable>(
        id: some Hashable & Sendable,
        lifetime: Channel<Action>.Lifetime = .permanent,
        _ transform: @escaping @Sendable (Output) -> Action
    ) -> Channel<Action> {
        let p = Unchecked(value: self)
        return Channel(id: id, lifetime: lifetime) { dispatch in
            let c = p.value.sink(receiveValue: { dispatch(transform($0)) })
            return .cancelOnly { c.cancel() }
        }
    }
}

extension Publisher where Failure: Error {
    /// Bridges a failable `Publisher<Output, Failure>` to a ``Channel`` via a `Result` transform.
    ///
    /// Each value is delivered as `.success`; a terminating error is delivered as `.failure`, after
    /// which the publisher is done (the channel stays registered until the state stops implying it,
    /// then the no-op `cancel` runs). Use a `Result` action case so the reducer stays deterministic.
    ///
    /// - Parameters:
    ///   - id: The channel key.
    ///   - lifetime: ``Channel/Lifetime`` (default `.permanent`).
    ///   - transform: Maps each `Result<Output, Failure>` to an `Action`.
    public func asChannel<Action: Sendable>(
        id: some Hashable & Sendable,
        lifetime: Channel<Action>.Lifetime = .permanent,
        _ transform: @escaping @Sendable (Result<Output, Failure>) -> Action
    ) -> Channel<Action> {
        let p = Unchecked(value: self)
        return Channel(id: id, lifetime: lifetime) { dispatch in
            let c = p.value.sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion { dispatch(transform(.failure(error))) }
                },
                receiveValue: { dispatch(transform(.success($0))) }
            )
            return .cancelOnly { c.cancel() }
        }
    }
}
#endif
