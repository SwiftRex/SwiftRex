import CoreFP
import Hourglass
@testable import SwiftRex
import Testing

// MARK: - listen (supervise) + send (broadcast) rendezvous on a shared id — the Elm socket model

@Suite("Channel listen/send rendezvous")
@MainActor
struct ChannelRendezvousTests {
    private enum A: Sendable, Equatable { case received(String) }

    private func makeEngine(_ received: LockProtected<[A]>) -> EffectEngine<A> {
        EffectEngine<A>(
            clock: ImmediateClock().eraseToAnyClock(),
            send: { d in received.mutate { $0.append(d.action) } }
        )
    }

    private func reconcile(_ engine: EffectEngine<A>, _ channels: [Channel<A>]) {
        engine.reconcile(channels.map { $0.reconcileEntry })
    }

    /// A value-less "socket" channel: piped writes land in `written`, teardown bumps `closed`.
    private func socket(written: LockProtected<[String]>, closed: LockProtected<Int>) -> Channel<A> {
        Channel(id: "socket") { _ in
            ChannelHandler(
                receive: { value in written.mutate { $0.append(value) } },
                cancel: { closed.mutate { $0 += 1 } }
            )
        }
    }

    @Test func openingDeliversNothing() {
        let written = LockProtected([String]())
        let closed = LockProtected(0)
        let engine = makeEngine(LockProtected([A]()))

        reconcile(engine, [socket(written: written, closed: closed)])
        #expect(written.value.isEmpty)         // value-less open: no spurious initial send
        #expect(closed.value == 0)
    }

    @Test func broadcastReachesTheSupervisedSocketBySharedId() {
        let written = LockProtected([String]())
        let closed = LockProtected(0)
        let engine = makeEngine(LockProtected([A]()))

        // listen: open "socket"
        reconcile(engine, [socket(written: written, closed: closed)])

        // send: action-driven broadcasts route into the SAME "socket" — no reopening
        engine.schedule(Effect<A>.broadcast("hi", channel: "socket").components[0])
        engine.schedule(Effect<A>.broadcast("hi", channel: "socket").components[0])  // same value twice → both sent
        engine.schedule(Effect<A>.broadcast("bye", channel: "socket").components[0])
        #expect(written.value == ["hi", "hi", "bye"])   // no dedup; rendezvous on the shared id
        #expect(closed.value == 0)                       // never reopened or torn down

        // leaving the desired set closes it
        reconcile(engine, [])
        #expect(closed.value == 1)
    }

    @Test func broadcastIntoAnAbsentChannelIsDropped() {
        let engine = makeEngine(LockProtected([A]()))
        // Nothing open under "socket" → broadcast never opens anything; the value is dropped.
        engine.schedule(Effect<A>.broadcast("hi", channel: "socket").components[0])
        #expect(Bool(true))   // reaching here without a crash is the assertion
    }

    @Test func differentIdTypesDoNotCollide() {
        let writtenA = LockProtected([String]())
        let writtenB = LockProtected([String]())
        let engine = makeEngine(LockProtected([A]()))

        reconcile(engine, [
            Channel(id: FeatureA.socket) { _ in
                ChannelHandler(receive: { v in writtenA.mutate { $0.append(v) } }, cancel: {})
            },
            Channel(id: FeatureB.socket) { _ in
                ChannelHandler(receive: { v in writtenB.mutate { $0.append(v) } }, cancel: {})
            }
        ])

        // Same case name, different types → distinct keys → broadcasts land in the right socket.
        engine.schedule(Effect<A>.broadcast("a", channel: FeatureA.socket).components[0])
        engine.schedule(Effect<A>.broadcast("b", channel: FeatureB.socket).components[0])
        #expect(writtenA.value == ["a"])
        #expect(writtenB.value == ["b"])
    }
}

private enum FeatureA: Hashable, Sendable { case socket }
private enum FeatureB: Hashable, Sendable { case socket }
