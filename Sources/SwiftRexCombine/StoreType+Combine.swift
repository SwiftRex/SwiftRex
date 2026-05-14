#if canImport(Combine)
@preconcurrency import Combine
import SwiftRex

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
        Task { @MainActor [weak self, store] in
            guard let self else { return }
            self.token = store.observe(didChange: { @MainActor [weak self, store] in
                _ = self?.subscriber?.receive(store.state)
            })
        }
    }

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
        token?.cancel()
        token = nil
        subscriber = nil
    }
}
#endif
