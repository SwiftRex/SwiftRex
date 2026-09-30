// SPDX-License-Identifier: Apache-2.0

#if canImport(Combine)
    @preconcurrency import Combine
    import SwiftRex

    // MARK: - StateStream is a Publisher

    /// A store's ``SwiftRex/StateStream`` **is** a Combine `Publisher` — no conversion needed:
    ///
    /// ```swift
    /// store.stateStream
    ///     .map(\.username)
    ///     .removeDuplicates()
    ///     .sink { name in nameLabel.text = name }
    ///     .store(in: &cancellables)
    /// ```
    ///
    /// - **Current value first**, then every change — like a `CurrentValueSubject`, without the subject: nothing
    ///   runs until a subscriber arrives, and each subscriber gets its own subscription.
    /// - **Delivered on the main actor** — synchronously when subscribing from the main thread (the normal
    ///   SwiftUI/UIKit case), after one hop otherwise. Move work elsewhere with `receive(on:)` if you need to.
    /// - **Demand is honoured with the latest value**: while the subscriber has no outstanding demand, only the
    ///   newest state is kept and delivered when demand arrives — state, unlike events, never needs a backlog.
    /// - Cancelling removes the observer from the store.
    ///
    /// `StateStream`'s own `map`/`removeDuplicates` (which keep it a `StateStream`, still a `Publisher`) take
    /// precedence over Combine's operators of the same names; the rest of Combine's operators apply as usual.
    extension StateStream: Publisher {
        public typealias Output = State
        public typealias Failure = Never

        nonisolated public func receive<S: Subscriber>(subscriber: S) where S.Input == State, S.Failure == Never {
            subscriber.receive(subscription: StateStreamSubscription(stream: self, subscriber: subscriber))
        }
    }

    // All mutable state is touched only on the main actor: every entry point (`request`, `cancel`) hops there
    // first — synchronously when already on the main thread. Combine may call those entry points from any thread,
    // hence the unchecked conformance.
    private final class StateStreamSubscription<State: Sendable, S: Subscriber>: Subscription, @unchecked Sendable
    where S.Input == State, S.Failure == Never {
        private let stream: StateStream<State>
        private var subscriber: S?
        private var token: UISubscriptionToken?
        private var demand: Subscribers.Demand = .none
        private var pending: State?
        private var started = false

        init(stream: StateStream<State>, subscriber: S) {
            self.stream = stream
            self.subscriber = subscriber
        }

        func request(_ more: Subscribers.Demand) {
            onMainActor { [self] in
                demand += more
                if !started {
                    started = true
                    let (current, token) = stream.subscribe { [weak self] in self?.receive($0) }
                    self.token = token
                    pending = current
                }
                drain()
            }
        }

        func cancel() {
            onMainActor { [self] in
                token = nil
                subscriber = nil
                pending = nil
            }
        }

        @MainActor
        private func receive(_ value: State) {
            pending = value
            drain()
        }

        @MainActor
        private func drain() {
            while demand > 0, let value = pending, let subscriber {
                pending = nil
                demand -= 1
                demand += subscriber.receive(value)
            }
        }
    }

#endif
