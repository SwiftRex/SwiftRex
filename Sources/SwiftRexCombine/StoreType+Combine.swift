#if canImport(Combine)
@preconcurrency import Combine
import SwiftRex

// MARK: - Store observation as Publisher

extension StoreType {
    /// A cold `Publisher<State, Never>` that emits the current state after every mutation.
    ///
    /// Subscribes lazily — ``StoreType/observe(willChange:didChange:)`` is only called when a
    /// Combine subscriber attaches. Each emission reads ``StoreType/state`` once (one value-type
    /// copy; O(1) amortised for CoW-backed states). Use `.receive(on:)` to move onto a scheduler
    /// if you need to process state off the main actor.
    ///
    /// Each subscriber gets its own independent ``SubscriptionToken``; cancelling the
    /// `AnyCancellable` removes the observer from the store immediately.
    ///
    /// ```swift
    /// store.publisher
    ///     .map(\.username)
    ///     .removeDuplicates()
    ///     .receive(on: RunLoop.main)
    ///     .sink { [weak self] name in self?.nameLabel.text = name }
    ///     .store(in: &cancellables)
    /// ```
    ///
    /// For SwiftUI use, prefer ``asObservableObject()`` (iOS 15) or ``asObservableStore()``
    /// (iOS 17), which wire `@ObjectWillChange` and `@Observable` respectively.
    public var publisher: StorePublisher<Self> { StorePublisher(store: self) }
}

/// A cold Combine `Publisher` backed by a ``StoreType``.
///
/// `StorePublisher` conforms to `Publisher<Output: State, Failure: Never>`. Each subscriber
/// triggers a separate call to ``StoreType/observe(willChange:didChange:)`` and receives a new
/// ``SubscriptionToken``. Cancelling the subscription token removes the observer from the store.
///
/// You do not typically create `StorePublisher` directly; instead use the ``StoreType/publisher``
/// property:
///
/// ```swift
/// store.publisher   // → StorePublisher<MyStore>
/// ```
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
