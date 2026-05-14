@preconcurrency import ReactiveSwift
import SwiftRex

// MARK: - Store observation as SignalProducer

extension StoreType {
    /// A cold `SignalProducer<State, Never>` that sends the current state after every mutation.
    ///
    /// Observation is lazy — ``StoreType/observe(willChange:didChange:)`` is only called when
    /// the producer is started via `start()` or `startWithValues`. Each started instance
    /// creates an independent ``SubscriptionToken``; ending the `Lifetime` (via `lifetime.end`)
    /// cancels the token and removes the observer from the store.
    ///
    /// Each emission reads ``StoreType/state`` once immediately after the mutation on the
    /// `@MainActor`.
    ///
    /// ```swift
    /// store.signal
    ///     .map(\.username)
    ///     .skipRepeats()
    ///     .startWithValues { [weak self] name in self?.nameLabel.text = name }
    ///
    /// // Bridge to Effect for middleware use
    /// Effect<AppAction>.deferredStream(
    ///     store.stream,
    ///     AppAction.stateChanged
    /// )
    /// ```
    ///
    /// To create an ``Effect`` directly from this producer, use one of the
    /// ``SignalProducer/asEffect`` overloads provided by `SwiftRexReactiveSwift`.
    public var signal: SignalProducer<State, Never> {
        SignalProducer { [self] observer, lifetime in
            let token = self.observe(didChange: { @MainActor [self] in
                observer.send(value: self.state)
            })
            lifetime.observeEnded { token.cancel() }
        }
    }
}
