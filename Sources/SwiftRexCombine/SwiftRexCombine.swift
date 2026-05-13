 @preconcurrency import Combine
import SwiftRex

private struct Unchecked<T>: @unchecked Sendable { let value: T }

// MARK: - Publisher → Effect bridges
//
//   Case A   Publisher<Action, Never>               .asEffect(scheduling:)
//            Output is already the Action — new ActionSource from call site.
//
//   Case A2  Publisher<DispatchedAction<A>, Never>  .asEffect(scheduling:)
//            Output is pre-sourced — dispatcher forwarded unchanged, no new ActionSource.
//
//   Case B   Publisher<Output, Never>               .asEffect(_ transform:scheduling:)
//            Infallible; user maps Output → Action.
//
//   Case C   Publisher<Output, Failure: Error>      .asEffect(_ transform:scheduling:)
//            Failable; user maps Result<Output, Failure> → Action.
//
// Completion: `complete()` fires on `.finished` or after the error action (Case C).
// Cancellation suppresses all further Combine callbacks including completion.

extension Publisher where Failure == Never {
    /// Bridges a `Publisher<Action, Never>` to `Effect<Action>`.
    /// Call-site is captured as the dispatcher source.
    public func asEffect(
        scheduling: EffectScheduling = .immediately,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Output> where Output: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Output>.Component(subscribe: { send, complete in
                let c = p.value.sink(
                    receiveCompletion: { _ in complete() },
                    receiveValue: { send(DispatchedAction($0, dispatcher: source)) }
                )
                return SubscriptionToken { c.cancel() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges a `Publisher<DispatchedAction<Action>, Never>` to `Effect<Action>`.
    /// The existing dispatcher is forwarded unchanged — no new ActionSource is created.
    public func asEffect<Action: Sendable>(
        scheduling: EffectScheduling = .immediately
    ) -> Effect<Action> where Output == DispatchedAction<Action> {
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let c = p.value.sink(
                    receiveCompletion: { _ in complete() },
                    receiveValue: { send($0) }
                )
                return SubscriptionToken { c.cancel() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges a `Publisher<Output, Never>` to `Effect<Action>` by mapping each value.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Output) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let c = p.value.sink(
                    receiveCompletion: { _ in complete() },
                    receiveValue: { send(DispatchedAction(transform($0), dispatcher: source)) }
                )
                return SubscriptionToken { c.cancel() }
            }, scheduling: scheduling)
        ])
    }
}

extension Publisher where Failure: Error {
    /// Bridges a failable `Publisher<Output, Failure>` to `Effect<Action>` via Result.
    ///
    /// Each value arrives as `.success`; a failure arrives as `.failure` and is dispatched
    /// before `complete()` fires.
    ///
    /// ```swift
    /// apiPublisher.asEffect(AppAction.didFetch)
    /// // enum AppAction { case didFetch(Result<MyModel, DecodingError>) }
    /// ```
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Result<Output, Failure>) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let c = p.value.sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            send(DispatchedAction(transform(.failure(error)), dispatcher: source))
                        }
                        complete()
                    },
                    receiveValue: { send(DispatchedAction(transform(.success($0)), dispatcher: source)) }
                )
                return SubscriptionToken { c.cancel() }
            }, scheduling: scheduling)
        ])
    }
}

// MARK: - Fire and forget (Publisher)

extension Effect {
    /// Subscribes to `p`, ignoring all values and errors, and calls `complete` on finish.
    /// Use with `|>` for a pipeline style: `myPublisher |> Effect.fireAndForget`.
    public static func fireAndForget<P: Publisher>(_ p: P) -> Self {
        let p = Unchecked(value: p)
        return Effect(components: [
            Component(subscribe: { _, complete in
                let c = p.value.sink(
                    receiveCompletion: { _ in complete() },
                    receiveValue: { _ in }
                )
                return SubscriptionToken { c.cancel() }
            }, scheduling: .immediately)
        ])
    }
}

// MARK: - Store observation as Publisher

extension StoreType {
    /// A `Publisher` that emits the current state after every mutation.
    ///
    /// Subscribes to the store lazily — `store.observe` is only called when a Combine
    /// subscriber arrives. Each emission reads `store.state` once (one struct copy, O(1)
    /// amortised for CoW-backed states). Use `.receive(on:)` to hop to a scheduler if needed.
    ///
    /// ```swift
    /// store.publisher
    ///     .map(\.username)
    ///     .removeDuplicates()
    ///     .sink { print($0) }
    ///     .store(in: &cancellables)
    /// ```
    public var publisher: StorePublisher<Self> { StorePublisher(store: self) }
}

/// A cold `Publisher` backed by a `StoreType`. A new `SubscriptionToken` is created per
/// subscriber; cancelling the `AnyCancellable` removes the observer from the store.
public struct StorePublisher<S: StoreType>: Publisher {
    public typealias Output  = S.State
    public typealias Failure = Never

    let store: S

    public func receive<Sub: Subscriber>(subscriber: Sub)
    where Sub.Input == S.State, Sub.Failure == Never {
        subscriber.receive(subscription: StoreSubscription(store: store, subscriber: subscriber))
    }
}

private final class StoreSubscription<S: StoreType, Sub: Subscriber>: Subscription, @unchecked Sendable
where Sub.Input == S.State, Sub.Failure == Never {

    private var subscriber: Sub?
    private var token: SubscriptionToken?

    init(store: S, subscriber: Sub) {
        self.subscriber = subscriber
        // Hop to MainActor to register the observer; in practice callers are already @MainActor.
        Task { @MainActor [weak self, store] in
            guard let self else { return }
            self.token = store.observe(didChange: { @MainActor [weak self, store] in
                _ = self?.subscriber?.receive(store.state)
            })
        }
    }

    func request(_ demand: Subscribers.Demand) {}   // demand ignored — store pushes at its own pace

    func cancel() {
        token?.cancel()
        token = nil
        subscriber = nil
    }
}
