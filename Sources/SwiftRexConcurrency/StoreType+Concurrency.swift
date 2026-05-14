import CoreFP
import SwiftRex

// MARK: - Store observation as DeferredStream

extension StoreType where State: Sendable {
    /// A lazy `DeferredStream<State>` that yields the current state after every mutation.
    /// The store is only observed when iteration begins — each new iterator creates an
    /// independent store subscription.
    public var stream: DeferredStream<State> {
        DeferredStream { [self] in
            AsyncStream { continuation in
                Task { @MainActor [self] in
                    let token = self.observe(didChange: { @MainActor [self] in
                        continuation.yield(self.state)
                    })
                    continuation.onTermination = { _ in token.cancel() }
                }
            }
        }
    }
}
