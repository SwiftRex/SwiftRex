@preconcurrency import ReactiveSwift
import SwiftRex

// MARK: - Store observation as SignalProducer

extension StoreType {
    /// A cold `SignalProducer<State, Never>` that sends the current state after every mutation.
    /// Observation only begins when the producer is started — each `start()` creates an
    /// independent store subscription.
    public var signal: SignalProducer<State, Never> {
        SignalProducer { [self] observer, lifetime in
            let token = self.observe(didChange: { @MainActor [self] in
                observer.send(value: self.state)
            })
            lifetime.observeEnded { token.cancel() }
        }
    }
}
