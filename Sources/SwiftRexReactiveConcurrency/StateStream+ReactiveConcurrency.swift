// SPDX-License-Identifier: Apache-2.0

#if ReactiveConcurrency
    import ReactiveConcurrency
    import SwiftRex

    // MARK: - StateStream as a ReactiveConcurrency Publisher

    extension StateStream {
        /// A store's state over time as a ReactiveConcurrency `Publisher<State, Never>` (a concrete type in that
        /// library, so this is a conversion rather than a conformance):
        ///
        /// ```swift
        /// store.stateStream.asPublisher
        ///     .map(\.username)
        ///     .removeDuplicates()
        /// ```
        ///
        /// The current value first, then every change. The publisher's body runs asynchronously, so it hops onto
        /// the main actor once to subscribe; values are observed there. Cancelling removes the observer.
        nonisolated public var asPublisher: Publisher<State, Never> {
            Publisher { [self] continuation in
                let token = await MainActor.run {
                    observe { continuation.yield($0) }
                }
                await continuation.suspendUntilCancelled()
                await MainActor.run { token.cancel() }
            }
        }
    }
#endif
