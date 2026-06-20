import CoreFP
import Hourglass
@testable import SwiftRex
import Testing

// MARK: - Reaction — state-driven desired-effect source

@Suite("Reaction")
@MainActor
struct ReactionTests {
    private struct AppState: Sendable {
        var isConnected = false
        var outbox = 0
    }

    private func makeEngine(_ received: LockProtected<[Int]>) -> EffectEngine<Int> {
        EffectEngine<Int>(
            clock: ImmediateClock().eraseToAnyClock(),
            send: { d in received.mutate { $0.append(d.action) } }
        )
    }

    // MARK: Monoid

    @Test func identityDesiresNothing() {
        let reaction = Reaction<AppState, Int>.identity
        #expect(reaction.react(AppState(isConnected: true)).isEmpty)
    }

    @Test func combineUnionsDesiredSets() {
        let a = Reaction<AppState, Int> { _ in [.effect(id: "a", .just(1))] }
        let b = Reaction<AppState, Int> { _ in [.effect(id: "b", .just(2))] }
        let combined = Reaction.combine(a, b)
        #expect(combined.react(AppState()).count == 2)
    }

    @Test func identityIsTheCombineUnit() {
        let r = Reaction<AppState, Int> { _ in [.effect(id: "x", .just(1))] }
        #expect(Reaction.combine(.identity, r).react(AppState()).count == 1)
        #expect(Reaction.combine(r, .identity).react(AppState()).count == 1)
    }

    // MARK: Reconcile through the engine

    @Test func channelStartsWhileConnectedAndCancelsWhenDisconnected() {
        let log = LockProtected([Int]())
        let cancels = LockProtected([String]())
        let engine = makeEngine(LockProtected([Int]()))

        let reaction = Reaction<AppState, Int> { state in
            guard state.isConnected else { return [] }
            return [
                .channel(id: "socket", value: state.outbox) { _, _ in
                    ChannelHandler(
                        receive: { v in log.mutate { $0.append(v) } },
                        cancel: { cancels.mutate { $0.append("socket") } }
                    )
                }
            ]
        }

        engine.reconcile(reaction.reconcileEntries(AppState(isConnected: true, outbox: 1)))
        #expect(log.value == [1])              // opened + piped the first outbox value
        #expect(cancels.value.isEmpty)

        engine.reconcile(reaction.reconcileEntries(AppState(isConnected: false)))
        #expect(cancels.value == ["socket"])   // condition false → reconciler cancels it
    }

    @Test func channelValueChangePipesIntoTheSameLiveChannel() {
        let log = LockProtected([Int]())
        let cancels = LockProtected([String]())
        let engine = makeEngine(LockProtected([Int]()))

        let reaction = Reaction<AppState, Int> { state in
            [
                .channel(id: "socket", value: state.outbox) { _, _ in
                    ChannelHandler(
                        receive: { v in log.mutate { $0.append(v) } },
                        cancel: { cancels.mutate { $0.append("socket") } }
                    )
                }
            ]
        }

        engine.reconcile(reaction.reconcileEntries(AppState(outbox: 1)))
        engine.reconcile(reaction.reconcileEntries(AppState(outbox: 1)))  // unchanged → no-op
        engine.reconcile(reaction.reconcileEntries(AppState(outbox: 2)))  // changed → pipe 2
        #expect(log.value == [1, 2])           // inferred version from value drove the pipe
        #expect(cancels.value.isEmpty)         // never torn down across the value change
    }

    @Test func presenceOnlyOneShotStartsOnceWhilePresent() {
        let received = LockProtected([Int]())
        let engine = makeEngine(received)

        let reaction = Reaction<AppState, Int> { state in
            state.isConnected ? [.effect(id: "ping", .just(42))] : []
        }

        engine.reconcile(reaction.reconcileEntries(AppState(isConnected: true)))
        engine.reconcile(reaction.reconcileEntries(AppState(isConnected: true)))  // still present → no re-fire
        #expect(received.value == [42])

        engine.reconcile(reaction.reconcileEntries(AppState(isConnected: false)))  // drops out
        engine.reconcile(reaction.reconcileEntries(AppState(isConnected: true)))   // re-enters → fires again
        #expect(received.value == [42, 42])
    }

    @Test func versionedOneShotReRunsWhenVersionChanges() {
        let received = LockProtected([Int]())
        let engine = makeEngine(received)

        let reaction = Reaction<AppState, Int> { state in
            [.effect(id: "fetch", version: state.outbox, .just(state.outbox))]
        }

        engine.reconcile(reaction.reconcileEntries(AppState(outbox: 1)))
        engine.reconcile(reaction.reconcileEntries(AppState(outbox: 1)))  // same version → no re-fire
        engine.reconcile(reaction.reconcileEntries(AppState(outbox: 2)))  // version changed → re-fire
        #expect(received.value == [1, 2])
    }
}
