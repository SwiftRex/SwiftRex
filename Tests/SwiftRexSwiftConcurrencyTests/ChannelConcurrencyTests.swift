import SwiftRex
@testable import SwiftRexSwiftConcurrency
import Testing

// MARK: - AsyncSequence.asChannel — a long-lived subscription driven by a real Store's supervise axis.

@Suite("Channel+Concurrency: AsyncSequence.asChannel")
@MainActor
struct ChannelConcurrencyTests {
    /// Test-only Sendable box holding an `AsyncStream` and its continuation (touched only on `@MainActor`).
    private final class Feed: @unchecked Sendable {
        let stream: AsyncStream<Int>
        let continuation: AsyncStream<Int>.Continuation
        init() {
            var c: AsyncStream<Int>.Continuation!
            stream = AsyncStream { c = $0 }
            continuation = c
        }
    }

    private struct S: Sendable, Equatable {
        var listening = false
        var received: [Int] = []
    }

    private enum A: Sendable, Equatable {
        case listen, stop
        case got(Int)
    }

    private let reducer = Behavior<A, S, Feed>.handle { action, _ in
        switch action {
        case .listen: .reduce { $0.listening = true }
        case .stop: .reduce { $0.listening = false }
        case .got(let v): .reduce { $0.received.append(v) }
        }
    }

    private func poll(until condition: @MainActor () -> Bool) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
    }

    @Test func iteratesInOrderWhileDesiredThenCancelsOnTeardown() async {
        let feed = Feed()
        let supervisor = Behavior<A, S, Feed>.supervise { state in
            Supervision { env in state.listening ? [env.stream.asChannel(id: "events", A.got)] : [] }
        }
        let store = Store(initial: S(), behavior: .combine(reducer, supervisor), environment: feed)

        store.dispatch(.listen)                          // opens the channel; the Task starts iterating
        feed.continuation.yield(1)
        feed.continuation.yield(2)
        await poll { store.state.received == [1, 2] }
        #expect(store.state.received == [1, 2])          // elements dispatched in order, after setup

        store.dispatch(.stop)                            // desired set empties → channel cancelled
        await poll { !store.state.listening }
        feed.continuation.yield(3)                       // produced after the iterating Task is cancelled
        for _ in 0..<30 { await Task.yield() }
        #expect(store.state.received == [1, 2])          // 3 never delivered — iteration was torn down
    }
}
