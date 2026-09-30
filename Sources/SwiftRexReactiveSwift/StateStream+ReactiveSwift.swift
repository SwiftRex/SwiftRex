// SPDX-License-Identifier: Apache-2.0

#if ReactiveSwift
    @preconcurrency import ReactiveSwift
    import SwiftRex

    // MARK: - StateStream is a SignalProducerConvertible

    /// A store's ``SwiftRex/StateStream`` **is** a ReactiveSwift `SignalProducerConvertible` — take its `producer`:
    ///
    /// ```swift
    /// store.stateStream.producer
    ///     .map(\.username)
    ///     .skipRepeats()
    ///     .startWithValues { name in nameLabel.text = name }
    /// ```
    ///
    /// The current value first, then every change; delivered on the main actor — synchronously when started from
    /// the main thread, after one hop otherwise. Disposing the lifetime removes the observer from the store.
    extension StateStream: SignalProducerConvertible {
        nonisolated public var producer: SignalProducer<State, Never> {
            SignalProducer { [self] observer, lifetime in
                let subscription = ProducerStateSubscription<State>()
                onMainActor {
                    subscription.token = observe { observer.send(value: $0) }
                }
                lifetime.observeEnded { onMainActor { subscription.token = nil } }
            }
        }
    }

    // The token of one subscription; created and released only on the main actor.
    private final class ProducerStateSubscription<State>: @unchecked Sendable {
        @MainActor var token: UISubscriptionToken?
    }

#endif
