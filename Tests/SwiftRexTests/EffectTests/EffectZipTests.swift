import XCTest
import Foundation
@testable import SwiftRex

final class EffectZipTests: XCTestCase {
    func testZipCombinesBothValues() {
        let received = LockProtected([(Int, String)]())
        _ = Effect<Int>.just(1)
            .zip(Effect<String>.just("a"))
            .components[0].subscribe { d in received.mutate { $0.append(d.action) } }
        XCTAssertEqual(received.value.map(\.0), [1])
        XCTAssertEqual(received.value.map(\.1), ["a"])
    }

    func testZipWithAppliesFunction() {
        let received = LockProtected([String]())
        _ = Effect<Int>.just(3)
            .zipWith(Effect<Int>.just(4)) { "\($0)+\($1)=\($0 + $1)" }
            .components[0].subscribe { d in received.mutate { $0.append(d.action) } }
        XCTAssertEqual(received.value, ["3+4=7"])
    }

    func testZipPreservesDispatcherOfCompletingPair() {
        let line: UInt = #line
        let received = LockProtected([DispatchedAction<(Int, String)>]())
        _ = Effect<Int>.just(1, line: line)
            .zip(Effect<String>.just("b"))
            .components[0].subscribe { d in received.mutate { $0.append(d) } }
        // Both fire synchronously; left fires first, so dispatcher comes from right
        XCTAssertEqual(received.value.count, 1)
    }

    func testZipOnlyDispatchesOnce() {
        let received = LockProtected([(Int, Int)]())
        _ = Effect<Int>.sequence([1, 2, 3])
            .zip(Effect<Int>.just(10))
            .components[0].subscribe { d in received.mutate { $0.append(d.action) } }
        // sequence fires 1, 2, 3 but zip only pairs the first from each side
        XCTAssertEqual(received.value.count, 1)
        XCTAssertEqual(received.value[0].0, 1)
        XCTAssertEqual(received.value[0].1, 10)
    }

    func testZipEmptyLeftProducesNothing() {
        let received = LockProtected([(Int, Int)]())
        _ = Effect<Int>.empty
            .zip(Effect<Int>.just(5))
            .components[0].subscribe { d in received.mutate { $0.append(d.action) } }
        XCTAssertTrue(received.value.isEmpty)
    }

    func testZipEmptyRightProducesNothing() {
        let received = LockProtected([(Int, Int)]())
        _ = Effect<Int>.just(5)
            .zip(Effect<Int>.empty)
            .components[0].subscribe { d in received.mutate { $0.append(d.action) } }
        XCTAssertTrue(received.value.isEmpty)
    }
}
