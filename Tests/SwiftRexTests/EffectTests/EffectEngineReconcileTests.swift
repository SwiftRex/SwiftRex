import CoreFP
import Hourglass
@testable import SwiftRex
import Testing

// MARK: - EffectEngine.reconcile — the state-driven (Channel) diff

@Suite("EffectEngine reconcile")
@MainActor
struct EffectEngineReconcileTests {
    private func makeEngine(_ received: LockProtected<[Int]>) -> EffectEngine<Int> {
        EffectEngine<Int>(
            clock: ImmediateClock().eraseToAnyClock(),
            send: { d in received.mutate { $0.append(d.action) } }
        )
    }

    private func entries(_ channels: [Channel<Int>]) -> [EffectEngine<Int>.ReconcileEntry] {
        channels.map { .init(component: $0.component, resetIdentity: $0.resetIdentity, broadcastIdentity: $0.broadcastIdentity) }
    }

    /// A broadcasting channel that records every delivered value into `log`, teardown into `cancels`.
    private func broadcaster(
        id: String,
        value: Int,
        log: LockProtected<[Int]>,
        cancels: LockProtected<[String]>
    ) -> Channel<Int> {
        Channel(id: id, broadcasting: .onChange(value)) { _ in
            ChannelHandler(
                receive: { v in log.mutate { $0.append(v) } },
                cancel: { cancels.mutate { $0.append(id) } }
            )
        }
    }

    @Test func opensDesiredAndCancelsWhenItDropsOut() {
        let log = LockProtected([Int]())
        let cancels = LockProtected([String]())
        let engine = makeEngine(LockProtected([Int]()))

        engine.reconcile(entries([broadcaster(id: "socket", value: 1, log: log, cancels: cancels)]))
        #expect(log.value == [1])              // opened → delivered 1 on connect
        #expect(cancels.value.isEmpty)

        engine.reconcile(entries([]))
        #expect(cancels.value == ["socket"])   // no longer desired → cancelled
    }

    @Test func unchangedBroadcastValueDeliversOnce() {
        let log = LockProtected([Int]())
        let cancels = LockProtected([String]())
        let engine = makeEngine(LockProtected([Int]()))
        for _ in 0..<3 {
            engine.reconcile(entries([broadcaster(id: "s", value: 1, log: log, cancels: cancels)]))
        }
        #expect(log.value == [1])              // delivered once — value never changed
        #expect(cancels.value.isEmpty)
    }

    @Test func changedBroadcastValuePipesIntoTheLiveChannel() {
        let log = LockProtected([Int]())
        let cancels = LockProtected([String]())
        let engine = makeEngine(LockProtected([Int]()))
        engine.reconcile(entries([broadcaster(id: "s", value: 1, log: log, cancels: cancels)]))
        engine.reconcile(entries([broadcaster(id: "s", value: 2, log: log, cancels: cancels)]))
        engine.reconcile(entries([broadcaster(id: "s", value: 3, log: log, cancels: cancels)]))
        #expect(log.value == [1, 2, 3])        // piped each change into the same channel
        #expect(cancels.value.isEmpty)         // never torn down
    }

    @Test func presenceOnlyChannelOpensOnce() {
        let received = LockProtected([Int]())
        let engine = makeEngine(received)
        // .nothing broadcasting → opens once, body dispatches a single action; no re-open.
        let channel = Channel<Int>(id: "s") { dispatch in dispatch(42); return .cancelOnly {} }
        for _ in 0..<3 { engine.reconcile(entries([channel])) }
        #expect(received.value == [42])
    }

    @Test func ephemeralRecreatesWhenResetKeyChanges() {
        let opens = LockProtected(0)
        let cancels = LockProtected(0)
        let engine = makeEngine(LockProtected([Int]()))
        func fetch(_ query: String) -> Channel<Int> {
            Channel(id: "search", lifetime: .ephemeral(resetKey: query)) { _ in
                opens.mutate { $0 += 1 }
                return .cancelOnly { cancels.mutate { $0 += 1 } }
            }
        }
        engine.reconcile(entries([fetch("a")]))   // open
        engine.reconcile(entries([fetch("a")]))   // same resetKey → no-op
        #expect(opens.value == 1)
        #expect(cancels.value == 0)
        engine.reconcile(entries([fetch("b")]))   // resetKey changed → recreate (cancel + reopen)
        #expect(opens.value == 2)
        #expect(cancels.value == 1)
    }

    @Test func independentKeysReconcileIndependently() {
        let log = LockProtected([Int]())
        let cancels = LockProtected([String]())
        let engine = makeEngine(LockProtected([Int]()))
        engine.reconcile(entries([
            broadcaster(id: "a", value: 1, log: log, cancels: cancels),
            broadcaster(id: "b", value: 10, log: log, cancels: cancels)
        ]))
        engine.reconcile(entries([broadcaster(id: "b", value: 10, log: log, cancels: cancels)]))
        #expect(cancels.value == ["a"])        // only a dropped out
        engine.reconcile(entries([]))
        #expect(cancels.value == ["a", "b"])
    }
}
