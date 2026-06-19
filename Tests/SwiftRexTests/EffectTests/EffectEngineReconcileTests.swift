import CoreFP
import Hourglass
@testable import SwiftRex
import Testing

// MARK: - EffectEngine.reconcile — the state-driven (Reaction) diff

@Suite("EffectEngine reconcile")
@MainActor
struct EffectEngineReconcileTests {
    /// Builds an engine whose produced actions land in `received`, driven by an `ImmediateClock`.
    private func makeEngine(_ received: LockProtected<[Int]>) -> EffectEngine<Int> {
        EffectEngine<Int>(
            clock: ImmediateClock().eraseToAnyClock(),
            send: { d in received.mutate { $0.append(d.action) } }
        )
    }

    /// A keyed channel that records every piped value into `log` and its teardown into `cancels`.
    private func channelEntry(
        id: String,
        value: Int,
        log: LockProtected<[Int]>,
        cancels: LockProtected<[String]>,
        valueIdentity: AnyHashableSendable?
    ) -> EffectEngine<Int>.ReconcileEntry {
        let effect = Effect<Int>.channel(value: value, scheduling: .keyed(id: id)) { _, _ in
            ChannelHandler(
                receive: { v in log.mutate { $0.append(v) } },
                cancel: { cancels.mutate { $0.append(id) } }
            )
        }
        return .init(component: effect.components[0], valueIdentity: valueIdentity)
    }

    @Test func startsDesiredAndCancelsWhenItDropsOut() {
        let log = LockProtected([Int]())
        let cancels = LockProtected([String]())
        let engine = makeEngine(LockProtected([Int]()))

        // First cycle: "socket" is desired → opens + delivers 1.
        engine.reconcile([channelEntry(id: "socket", value: 1, log: log, cancels: cancels, valueIdentity: AnyHashableSendable(1))])
        #expect(log.value == [1])
        #expect(cancels.value.isEmpty)

        // Next cycle: "socket" no longer desired → cancelled.
        engine.reconcile([])
        #expect(cancels.value == ["socket"])
    }

    @Test func unchangedValueIdentityProducesZeroOperations() {
        let log = LockProtected([Int]())
        let cancels = LockProtected([String]())
        let engine = makeEngine(LockProtected([Int]()))
        let id = AnyHashableSendable(7)

        engine.reconcile([channelEntry(id: "s", value: 1, log: log, cancels: cancels, valueIdentity: id)])
        engine.reconcile([channelEntry(id: "s", value: 1, log: log, cancels: cancels, valueIdentity: id)])
        engine.reconcile([channelEntry(id: "s", value: 1, log: log, cancels: cancels, valueIdentity: id)])

        #expect(log.value == [1])          // delivered once — identity never changed
        #expect(cancels.value.isEmpty)     // still desired across all three cycles
    }

    @Test func changedValueIdentityPipesIntoTheSameLiveChannel() {
        let log = LockProtected([Int]())
        let cancels = LockProtected([String]())
        let engine = makeEngine(LockProtected([Int]()))

        engine.reconcile([channelEntry(id: "s", value: 1, log: log, cancels: cancels, valueIdentity: AnyHashableSendable(1))])
        engine.reconcile([channelEntry(id: "s", value: 2, log: log, cancels: cancels, valueIdentity: AnyHashableSendable(2))])
        engine.reconcile([channelEntry(id: "s", value: 3, log: log, cancels: cancels, valueIdentity: AnyHashableSendable(3))])

        #expect(log.value == [1, 2, 3])    // piped each changed value into the same channel
        #expect(cancels.value.isEmpty)     // never torn down — the channel stayed alive
    }

    @Test func presenceOnlyEntryStartsOnceAndIsNotReScheduled() {
        let log = LockProtected([Int]())
        let cancels = LockProtected([String]())
        let engine = makeEngine(LockProtected([Int]()))

        // valueIdentity nil → presence-only. Three cycles, all desired.
        for _ in 0..<3 {
            engine.reconcile([channelEntry(id: "s", value: 9, log: log, cancels: cancels, valueIdentity: nil)])
        }
        #expect(log.value == [9])          // started once, never re-delivered
        #expect(cancels.value.isEmpty)
    }

    @Test func independentKeysReconcileIndependently() {
        let log = LockProtected([Int]())
        let cancels = LockProtected([String]())
        let engine = makeEngine(LockProtected([Int]()))

        func entryA(_ v: Int) -> EffectEngine<Int>.ReconcileEntry {
            channelEntry(id: "a", value: v, log: log, cancels: cancels, valueIdentity: AnyHashableSendable(v))
        }
        func entryB(_ v: Int) -> EffectEngine<Int>.ReconcileEntry {
            channelEntry(id: "b", value: v, log: log, cancels: cancels, valueIdentity: AnyHashableSendable(v))
        }

        engine.reconcile([entryA(1), entryB(10)])     // both start
        engine.reconcile([entryB(10)])                // a drops out → only a cancelled
        #expect(cancels.value == ["a"])
        engine.reconcile([])                          // b drops out
        #expect(cancels.value == ["a", "b"])
    }
}
