// SPDX-License-Identifier: Apache-2.0

// `StateStream` as an `AsyncSequence`, for `for await` consumers on the main actor.
//
// State is not a queue of events: a consumer that falls behind only needs the **latest** state, so the
// iterator keeps one pending value (a newer state replaces an unread one) instead of buffering history.
// The subscription starts when iteration starts and ends when the iterator is released or its task is
// cancelled.

extension StateStream: @MainActor AsyncSequence {
    public typealias Element = State

    public func makeAsyncIterator() -> Iterator {
        Iterator(latest: LatestValue(self))
    }

    /// Iterates the stream from the main actor: the current state first, then the newest state each time
    /// the loop asks for more (intermediate states a slow loop didn't get to are skipped).
    @MainActor
    public struct Iterator: @MainActor AsyncIteratorProtocol {
        let latest: LatestValue<State>

        public mutating func next() async -> State? {
            await latest.next()
        }
    }
}

/// The single pending value between a stream's observer and an iterating loop.
@MainActor
public final class LatestValue<Value: Sendable> {
    private var token: UISubscriptionToken?
    private var pending: Value?
    private var waiting: CheckedContinuation<Value?, Never>?
    private var finished = false

    init(_ stream: StateStream<Value>) {
        token = stream.observe { [weak self] value in self?.deliver(value) }
    }

    func next() async -> Value? {
        guard !finished, !Task.isCancelled else { return nil }
        if let value = pending {
            pending = nil
            return value
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { waiting = $0 }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish() }
        }
    }

    private func deliver(_ value: Value) {
        guard let continuation = waiting else {
            pending = value
            return
        }
        waiting = nil
        continuation.resume(returning: value)
    }

    private func finish() {
        finished = true
        token = nil
        let continuation = waiting
        waiting = nil
        continuation?.resume(returning: nil)
    }
}
