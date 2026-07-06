// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Foundation
@testable import SwiftRex
import Testing

// MARK: - Monoid

@Suite
struct EffectMonoidTests {
    @Test func identityHasNoComponents() {
        #expect(Effect<Int>.identity.components.isEmpty)
    }

    @Test func emptyIsIdentity() {
        #expect(Effect<Int>.empty.components.isEmpty)
    }

    @Test func combineAppendsComponents() {
        #expect(Effect.combine(Effect<Int>.just(1), Effect<Int>.just(2)).components.count == 2)
    }

    @Test func combineLeftIdentityLaw() {
        let e = Effect<Int>.just(42)
        #expect(Effect.combine(.identity, e).components.count == e.components.count)
    }

    @Test func combineRightIdentityLaw() {
        let e = Effect<Int>.just(42)
        #expect(Effect.combine(e, .identity).components.count == e.components.count)
    }

    @Test func combinePreservesIndividualScheduling() {
        let a = Effect<Int>.just(1).scheduling(.replacing(id: "a"))
        let b = Effect<Int>.just(2).scheduling(.debounce(id: "b", delay: .milliseconds(300)))
        let combined = Effect.combine(a, b)
        guard combined.components.count == 2 else { Issue.record("Expected 2 components"); return }
        #expect(combined.components[0].scheduling.id == AnyHashableSendable("a"))
        #expect(combined.components[0].scheduling.exclusive)
        #expect(combined.components[1].scheduling.id == AnyHashableSendable("b"))
        #expect(combined.components[1].scheduling.coalesce == .debounce(.milliseconds(300)))
    }
}

// MARK: - Convenience factories

@Suite
struct EffectConvenienceFactoryTests {
    @Test func justProducesOneComponent() {
        #expect(Effect<Int>.just(42).components.count == 1)
    }

    @Test func justDispatchesAction() {
        let received = LockProtected([Int]())
        subscribeAll(Effect<Int>.just(42)) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value == [42])
    }

    @Test func justCapturesCallSite() {
        let line: UInt = #line; let effect = Effect<Int>.just(1, line: line)
        let received = LockProtected([DispatchedAction<Int>]())
        subscribeAll(effect) { d in received.mutate { $0.append(d) } }
        #expect(received.value[0].dispatcher.line == line)
    }

    @Test func justCallsComplete() {
        let completed = LockProtected(false)
        subscribeAll(Effect<Int>.just(42), send: { _ in }, onComplete: { completed.set(true) })
        #expect(completed.value)
    }

    @Test func sequenceDispatchesAllActionsInOrder() {
        let received = LockProtected([Int]())
        subscribeAll(Effect<Int>.sequence([1, 2, 3])) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value == [1, 2, 3])
    }

    @Test func sequenceCallsComplete() {
        let completed = LockProtected(false)
        subscribeAll(Effect<Int>.sequence([1, 2, 3]), send: { _ in }, onComplete: { completed.set(true) })
        #expect(completed.value)
    }

    @Test func sequenceEmptyProducesNoActions() {
        let received = LockProtected([Int]())
        subscribeAll(Effect<Int>.sequence([])) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value.isEmpty)
    }
}

// MARK: - Forwarding factories

@Suite
struct EffectForwardingFactoryTests {
    private let source = ActionSource(file: "original.swift", function: "originalFunc()", line: 99)

    @Test func justDispatchedPreservesSource() {
        let dispatched = DispatchedAction(42, dispatcher: source)
        let received = LockProtected([DispatchedAction<Int>]())
        subscribeAll(Effect<Int>.just(dispatched)) { d in received.mutate { $0.append(d) } }
        #expect(received.value[0].dispatcher.file == "original.swift")
        #expect(received.value[0].dispatcher.line == 99)
        #expect(received.value[0].action == 42)
    }

    @Test func sequenceDispatchedPreservesAllSources() {
        let d1 = DispatchedAction(1, dispatcher: source)
        let d2 = DispatchedAction(2, dispatcher: ActionSource(file: "b.swift", function: "f()", line: 5))
        let received = LockProtected([DispatchedAction<Int>]())
        subscribeAll(Effect<Int>.sequence([d1, d2])) { d in received.mutate { $0.append(d) } }
        #expect(received.value[0].dispatcher.file == "original.swift")
        #expect(received.value[1].dispatcher.file == "b.swift")
    }
}

// MARK: - Scheduling modifier

@Suite
struct EffectSchedulingModifierTests {
    @Test func schedulingModifierReplacesAllComponents() {
        let combined = Effect.combine(Effect<Int>.just(1), Effect<Int>.just(2))
        let rescheduled = combined.scheduling(.replacing(id: "x"))
        #expect(rescheduled.components.allSatisfy {
            $0.scheduling.id == AnyHashableSendable("x") && $0.scheduling.exclusive
        })
    }
}

// MARK: - cancelInFlight sentinel

@Suite
struct EffectCancelInFlightTests {
    @Test func cancelInFlightHasOneComponent() {
        #expect(Effect<Int>.cancel(id: "search").components.count == 1)
    }

    @Test func cancelInFlightHasCancelScheduling() {
        let effect = Effect<Int>.cancel(id: "search")
        #expect(effect.components[0].scheduling.cancelsOnly)
        #expect(effect.components[0].scheduling.id == AnyHashableSendable("search"))
    }
}

// MARK: - map

@Suite
struct EffectMapTests {
    @Test func mapTransformsAction() {
        let received = LockProtected([String]())
        subscribeAll(Effect<Int>.just(5).map(String.init)) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value == ["5"])
    }

    @Test func mapPreservesDispatcher() {
        let line: UInt = #line; let effect = Effect<Int>.just(1, line: line)
        let received = LockProtected([DispatchedAction<String>]())
        subscribeAll(effect.map(String.init)) { d in received.mutate { $0.append(d) } }
        #expect(received.value[0].dispatcher.line == line)
    }

    @Test func mapPreservesComponentCount() {
        let combined = Effect.combine(Effect<Int>.just(1), Effect<Int>.just(2))
        #expect(combined.map(String.init).components.count == 2)
    }

    @Test func mapPreservesScheduling() {
        let effect = Effect<Int>.just(1).scheduling(.replacing(id: "x"))
        let mapped = effect.map { $0 * 2 }
        #expect(mapped.components[0].scheduling.id == AnyHashableSendable("x"))
        #expect(mapped.components[0].scheduling.exclusive)
    }

    @Test func mapThreadsComplete() {
        let completed = LockProtected(false)
        subscribeAll(Effect<Int>.just(1).map { $0 * 2 }, send: { _ in }, onComplete: { completed.set(true) })
        #expect(completed.value)
    }
}
