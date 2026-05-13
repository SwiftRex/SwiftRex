import XCTest
import Foundation
import CoreFP
@testable import SwiftRex

// MARK: - Monoid

final class EffectMonoidTests: XCTestCase {
    func testIdentityHasNoComponents() {
        XCTAssertTrue(Effect<Int>.identity.components.isEmpty)
    }

    func testEmptyIsIdentity() {
        XCTAssertTrue(Effect<Int>.empty.components.isEmpty)
    }

    func testCombineAppendsComponents() {
        XCTAssertEqual(Effect.combine(Effect<Int>.just(1), Effect<Int>.just(2)).components.count, 2)
    }

    func testCombineLeftIdentityLaw() {
        let e = Effect<Int>.just(42)
        XCTAssertEqual(Effect.combine(.identity, e).components.count, e.components.count)
    }

    func testCombineRightIdentityLaw() {
        let e = Effect<Int>.just(42)
        XCTAssertEqual(Effect.combine(e, .identity).components.count, e.components.count)
    }

    func testCombinePreservesIndividualScheduling() {
        let a = Effect<Int>.just(1).scheduling(.replacing(id: "a"))
        let b = Effect<Int>.just(2).scheduling(.debounce(id: "b", delay: 0.3))
        let combined = Effect.combine(a, b)
        guard combined.components.count == 2 else { XCTFail("Expected 2 components"); return }
        if case .replacing(let id) = combined.components[0].scheduling {
            XCTAssertEqual(id, AnyHashable("a"))
        } else { XCTFail("Expected .replacing") }
        if case .debounce(let id, _) = combined.components[1].scheduling {
            XCTAssertEqual(id, AnyHashable("b"))
        } else { XCTFail("Expected .debounce") }
    }
}

// MARK: - Convenience factories

final class EffectConvenienceFactoryTests: XCTestCase {
    func testJustProducesOneComponent() {
        XCTAssertEqual(Effect<Int>.just(42).components.count, 1)
    }

    func testJustDispatchesAction() {
        let received = LockProtected([Int]())
        subscribeAll(Effect<Int>.just(42)) { d in received.mutate { $0.append(d.action) } }
        XCTAssertEqual(received.value, [42])
    }

    func testJustCapturesCallSite() {
        let line: UInt = #line; let effect = Effect<Int>.just(1, line: line)
        let received = LockProtected([DispatchedAction<Int>]())
        subscribeAll(effect) { d in received.mutate { $0.append(d) } }
        XCTAssertEqual(received.value[0].dispatcher.line, line)
    }

    func testJustCallsComplete() {
        let completed = LockProtected(false)
        subscribeAll(Effect<Int>.just(42), send: { _ in }, onComplete: { completed.set(true) })
        XCTAssertTrue(completed.value)
    }

    func testSequenceDispatchesAllActionsInOrder() {
        let received = LockProtected([Int]())
        subscribeAll(Effect<Int>.sequence([1, 2, 3])) { d in received.mutate { $0.append(d.action) } }
        XCTAssertEqual(received.value, [1, 2, 3])
    }

    func testSequenceCallsComplete() {
        let completed = LockProtected(false)
        subscribeAll(Effect<Int>.sequence([1, 2, 3]), send: { _ in }, onComplete: { completed.set(true) })
        XCTAssertTrue(completed.value)
    }

    func testSequenceEmptyProducesNoActions() {
        let received = LockProtected([Int]())
        subscribeAll(Effect<Int>.sequence([])) { d in received.mutate { $0.append(d.action) } }
        XCTAssertTrue(received.value.isEmpty)
    }
}

// MARK: - Forwarding factories

final class EffectForwardingFactoryTests: XCTestCase {
    private let source = ActionSource(file: "original.swift", function: "originalFunc()", line: 99)

    func testJustDispatchedPreservesSource() {
        let dispatched = DispatchedAction(42, dispatcher: source)
        let received = LockProtected([DispatchedAction<Int>]())
        subscribeAll(Effect<Int>.just(dispatched)) { d in received.mutate { $0.append(d) } }
        XCTAssertEqual(received.value[0].dispatcher.file, "original.swift")
        XCTAssertEqual(received.value[0].dispatcher.line, 99)
        XCTAssertEqual(received.value[0].action, 42)
    }

    func testSequenceDispatchedPreservesAllSources() {
        let d1 = DispatchedAction(1, dispatcher: source)
        let d2 = DispatchedAction(2, dispatcher: ActionSource(file: "b.swift", function: "f()", line: 5))
        let received = LockProtected([DispatchedAction<Int>]())
        subscribeAll(Effect<Int>.sequence([d1, d2])) { d in received.mutate { $0.append(d) } }
        XCTAssertEqual(received.value[0].dispatcher.file, "original.swift")
        XCTAssertEqual(received.value[1].dispatcher.file, "b.swift")
    }
}

// MARK: - Scheduling modifier

final class EffectSchedulingModifierTests: XCTestCase {
    func testSchedulingModifierReplacesAllComponents() {
        let combined = Effect.combine(Effect<Int>.just(1), Effect<Int>.just(2))
        let rescheduled = combined.scheduling(.replacing(id: "x"))
        XCTAssertTrue(rescheduled.components.allSatisfy {
            if case .replacing(let id) = $0.scheduling { return id == AnyHashable("x") }
            return false
        })
    }
}

// MARK: - cancelInFlight sentinel

final class EffectCancelInFlightTests: XCTestCase {
    func testCancelInFlightHasOneComponent() {
        XCTAssertEqual(Effect<Int>.cancelInFlight(id: "search").components.count, 1)
    }

    func testCancelInFlightHasCancelScheduling() {
        let effect = Effect<Int>.cancelInFlight(id: "search")
        if case .cancelInFlight(let id) = effect.components[0].scheduling {
            XCTAssertEqual(id, AnyHashable("search"))
        } else { XCTFail("Expected .cancelInFlight scheduling") }
    }
}

// MARK: - map

final class EffectMapTests: XCTestCase {
    func testMapTransformsAction() {
        let received = LockProtected([String]())
        subscribeAll(Effect<Int>.just(5).map(String.init)) { d in received.mutate { $0.append(d.action) } }
        XCTAssertEqual(received.value, ["5"])
    }

    func testMapPreservesDispatcher() {
        let line: UInt = #line; let effect = Effect<Int>.just(1, line: line)
        let received = LockProtected([DispatchedAction<String>]())
        subscribeAll(effect.map(String.init)) { d in received.mutate { $0.append(d) } }
        XCTAssertEqual(received.value[0].dispatcher.line, line)
    }

    func testMapPreservesComponentCount() {
        let combined = Effect.combine(Effect<Int>.just(1), Effect<Int>.just(2))
        XCTAssertEqual(combined.map(String.init).components.count, 2)
    }

    func testMapPreservesScheduling() {
        let effect = Effect<Int>.just(1).scheduling(.replacing(id: "x"))
        let mapped = effect.map { $0 * 2 }
        if case .replacing(let id) = mapped.components[0].scheduling {
            XCTAssertEqual(id, AnyHashable("x"))
        } else { XCTFail("Expected .replacing scheduling preserved after map") }
    }

    func testMapThreadsComplete() {
        let completed = LockProtected(false)
        subscribeAll(Effect<Int>.just(1).map { $0 * 2 }, send: { _ in }, onComplete: { completed.set(true) })
        XCTAssertTrue(completed.value)
    }
}

