import XCTest
import Foundation
@testable import SwiftRex

// Helper: subscribe all components of an effect with the same send callback,
// mirroring what the Store does.
private func subscribeAll<A: Sendable>(
    _ effect: Effect<A>,
    send: @escaping @Sendable (DispatchedAction<A>) -> Void
) -> [SubscriptionToken] {
    effect.components.map { $0.subscribe(send) }
}

final class EffectZipTests: XCTestCase {
    func testZipCombinesBothValues() {
        let received = LockProtected([(Int, String)]())
        _ = subscribeAll(
            Effect<Int>.just(1).zip(Effect<String>.just("a"))
        ) { d in received.mutate { $0.append(d.action) } }
        XCTAssertEqual(received.value.map(\.0), [1])
        XCTAssertEqual(received.value.map(\.1), ["a"])
    }

    func testZipWithAppliesFunction() {
        let received = LockProtected([String]())
        _ = subscribeAll(
            Effect<Int>.just(3).zipWith(Effect<Int>.just(4)) { "\($0)+\($1)=\($0 + $1)" }
        ) { d in received.mutate { $0.append(d.action) } }
        XCTAssertEqual(received.value, ["3+4=7"])
    }

    func testZipUsesCallSiteAsDispatcher() {
        let line: UInt = #line
        let received = LockProtected([DispatchedAction<(Int, String)>]())
        _ = subscribeAll(
            Effect<Int>.just(1).zip(Effect<String>.just("b"), line: line)
        ) { d in received.mutate { $0.append(d) } }
        XCTAssertEqual(received.value.count, 1)
        XCTAssertEqual(received.value[0].dispatcher.line, line)
    }

    func testZipOnlyDispatchesOnce() {
        let received = LockProtected([(Int, Int)]())
        _ = subscribeAll(
            Effect<Int>.sequence([1, 2, 3]).zip(Effect<Int>.just(10))
        ) { d in received.mutate { $0.append(d.action) } }
        // sequence fires 1, 2, 3 but zip only pairs the first from each side
        XCTAssertEqual(received.value.count, 1)
        XCTAssertEqual(received.value[0].0, 1)
        XCTAssertEqual(received.value[0].1, 10)
    }

    func testZipEmptyLeftProducesNothing() {
        let received = LockProtected([(Int, Int)]())
        _ = subscribeAll(
            Effect<Int>.empty.zip(Effect<Int>.just(5))
        ) { d in received.mutate { $0.append(d.action) } }
        XCTAssertTrue(received.value.isEmpty)
    }

    func testZipEmptyRightProducesNothing() {
        let received = LockProtected([(Int, Int)]())
        _ = subscribeAll(
            Effect<Int>.just(5).zip(Effect<Int>.empty)
        ) { d in received.mutate { $0.append(d.action) } }
        XCTAssertTrue(received.value.isEmpty)
    }

    func testZipPreservesSchedulingFromBothSides() {
        let combined = Effect<Int>.just(1)
            .scheduling(.cancellable(id: "left"))
            .zip(Effect<Int>.just(2).scheduling(.debounce(id: "right", delay: 0.3)))
        // Components: [left with .cancellable, right with .debounce]
        XCTAssertEqual(combined.components.count, 2)
        if case .cancellable(let id) = combined.components[0].scheduling {
            XCTAssertEqual(id, AnyHashable("left"))
        } else { XCTFail("Expected .cancellable on left component") }
        if case .debounce(let id, _) = combined.components[1].scheduling {
            XCTAssertEqual(id, AnyHashable("right"))
        } else { XCTFail("Expected .debounce on right component") }
    }
}
