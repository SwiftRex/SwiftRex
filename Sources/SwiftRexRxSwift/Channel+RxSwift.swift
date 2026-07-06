// SPDX-License-Identifier: Apache-2.0

@preconcurrency import RxSwift
import SwiftRex

private struct Unchecked<T>: @unchecked Sendable { let value: T }

// MARK: - Observable/Infallible → Channel (state-driven, long-lived subscriptions)

//
// The `asChannel` counterpart of `asEffect`: where `asEffect` makes a one-shot effect, `asChannel`
// makes a long-lived ``Channel`` a `supervise` keeps alive. The Store subscribes once while the channel
// is desired, dispatches each `onNext` element as an action, and `dispose()`s the `Disposable` when the
// channel leaves the desired set.
//
// ## Timing — synchronous emission is safe
//
// A `BehaviorSubject`/`ReplaySubject` emits synchronously on `subscribe`, inside the channel body before
// the engine registers the channel. That is safe: every action a channel dispatches hops through the
// Store's `send` (`Task { @MainActor }`) onto a later turn, so an element emitted during subscription is
// captured and deferred — it cannot re-enter the in-flight reconcile, be lost, or double-open. The
// `Disposable` is captured only into the teardown closure, never the `onNext` path. The channel is a
// pure receiver (`cancelOnly`); for the *send* direction use `Effect.broadcast(_:channel:)`.

extension InfallibleType {
    /// Bridges an `Infallible<Action>` to a long-lived ``Channel`` keyed by `id`.
    public func asChannel(
        id: some Hashable & Sendable,
        lifetime: Channel<Element>.Lifetime = .permanent
    ) -> Channel<Element> where Element: Sendable {
        let o = Unchecked(value: self)
        return Channel(id: id, lifetime: lifetime) { dispatch in
            let d = o.value.subscribe(onNext: { dispatch($0) })
            return .cancelOnly { d.dispose() }
        }
    }

    /// Bridges an `Infallible<Element>` to a ``Channel`` by mapping each element to an action.
    public func asChannel<Action: Sendable>(
        id: some Hashable & Sendable,
        lifetime: Channel<Action>.Lifetime = .permanent,
        _ transform: @escaping @Sendable (Element) -> Action
    ) -> Channel<Action> {
        let o = Unchecked(value: self)
        return Channel(id: id, lifetime: lifetime) { dispatch in
            let d = o.value.subscribe(onNext: { dispatch(transform($0)) })
            return .cancelOnly { d.dispose() }
        }
    }
}

extension ObservableType {
    /// Bridges a failable `Observable<Element>` to a ``Channel`` via a `Result` transform — each value
    /// is `.success`; a terminating error is `.failure`, after which the sequence is done.
    public func asChannel<Action: Sendable>(
        id: some Hashable & Sendable,
        lifetime: Channel<Action>.Lifetime = .permanent,
        _ transform: @escaping @Sendable (Result<Element, Error>) -> Action
    ) -> Channel<Action> {
        let o = Unchecked(value: self)
        return Channel(id: id, lifetime: lifetime) { dispatch in
            let d = o.value.subscribe(
                onNext: { dispatch(transform(.success($0))) },
                onError: { dispatch(transform(.failure($0))) }
            )
            return .cancelOnly { d.dispose() }
        }
    }
}
