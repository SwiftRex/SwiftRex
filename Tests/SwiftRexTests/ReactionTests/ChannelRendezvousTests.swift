import CoreFP
import Hourglass
@testable import SwiftRex
import Testing

// MARK: - listen (reaction) + send (pipe) rendezvous on a shared id — the Elm socket model

@Suite("Channel listen/send rendezvous")
@MainActor
struct ChannelRendezvousTests {
    private struct S: Sendable { var connected = false }
    private enum A: Sendable, Equatable { case received(String) }

    private func makeEngine(_ received: LockProtected<[A]>) -> EffectEngine<A> {
        EffectEngine<A>(
            clock: ImmediateClock().eraseToAnyClock(),
            send: { d in received.mutate { $0.append(d.action) } }
        )
    }

    /// A reaction keeping a value-less "socket" alive while connected: piped writes land in `written`,
    /// teardown bumps `closed`.
    private func socketReaction(
        written: LockProtected<[String]>,
        closed: LockProtected<Int>
    ) -> Reaction<S, A> {
        Reaction<S, A> { state in
            guard state.connected else { return [] }
            return [
                Channel(id: "socket") { _ in
                    ChannelHandler(
                        receive: { value in written.mutate { $0.append(value) } },
                        cancel: { closed.mutate { $0 += 1 } }
                    )
                }
            ]
        }
    }

    @Test func openingDeliversNothing() {
        let written = LockProtected([String]())
        let closed = LockProtected(0)
        let engine = makeEngine(LockProtected([A]()))
        let reaction = socketReaction(written: written, closed: closed)

        engine.reconcile(reaction.reconcileEntries(S(connected: true)))
        #expect(written.value.isEmpty)         // value-less open: no spurious initial send
        #expect(closed.value == 0)
    }

    @Test func pipeReachesTheReactionOwnedSocketBySharedId() {
        let written = LockProtected([String]())
        let closed = LockProtected(0)
        let engine = makeEngine(LockProtected([A]()))
        let reaction = socketReaction(written: written, closed: closed)

        // listen: reaction opens "socket"
        engine.reconcile(reaction.reconcileEntries(S(connected: true)))

        // send: action-driven pipes route into the SAME "socket" — no reopening
        engine.schedule(Effect<A>.pipe("hi", into: "socket").components[0])
        engine.schedule(Effect<A>.pipe("hi", into: "socket").components[0])  // same value twice → both sent
        engine.schedule(Effect<A>.pipe("bye", into: "socket").components[0])
        #expect(written.value == ["hi", "hi", "bye"])   // no dedup; rendezvous on the shared id
        #expect(closed.value == 0)                       // never reopened or torn down

        // leaving the desired set closes it
        engine.reconcile(reaction.reconcileEntries(S(connected: false)))
        #expect(closed.value == 1)
    }

    @Test func pipeIntoAnAbsentChannelIsDropped() {
        let engine = makeEngine(LockProtected([A]()))
        // Nothing open under "socket" → pipe never opens anything; the value is dropped.
        engine.schedule(Effect<A>.pipe("hi", into: "socket").components[0])
        #expect(Bool(true))   // reaching here without a crash is the assertion
    }

    @Test func differentIdTypesDoNotCollide() {
        let writtenA = LockProtected([String]())
        let writtenB = LockProtected([String]())
        let engine = makeEngine(LockProtected([A]()))

        let reaction = Reaction<S, A> { _ in
            [
                Channel(id: FeatureA.socket) { _ in
                    ChannelHandler(receive: { v in writtenA.mutate { $0.append(v) } }, cancel: {})
                },
                Channel(id: FeatureB.socket) { _ in
                    ChannelHandler(receive: { v in writtenB.mutate { $0.append(v) } }, cancel: {})
                }
            ]
        }
        engine.reconcile(reaction.reconcileEntries(S()))

        // Same case name, different types → distinct keys → pipes land in the right socket.
        engine.schedule(Effect<A>.pipe("a", into: FeatureA.socket).components[0])
        engine.schedule(Effect<A>.pipe("b", into: FeatureB.socket).components[0])
        #expect(writtenA.value == ["a"])
        #expect(writtenB.value == ["b"])
    }
}

private enum FeatureA: Hashable, Sendable { case socket }
private enum FeatureB: Hashable, Sendable { case socket }
