import XCTest
import CoreFP
@testable import SwiftRex

final class ReducerLiftTests: XCTestCase {
    // MARK: - Helpers

    private struct GA { var local: Int?; var other: String? }
    private struct GS { var local: Int = 0; var other: Int = 99 }

    private let addAction = Reducer<Int, Int>.reduce { action, state in state += action }

    // MARK: - KeyPath: action + state

    func testLiftKeyPathActionStateAppliesWhenMatched() {
        let sut = addAction.lift(action: \GA.local, state: \GS.local)
        var state = GS()
        sut.reduce(GA(local: 5))(&state)
        XCTAssertEqual(state.local, 5)
        XCTAssertEqual(state.other, 99)
    }

    func testLiftKeyPathActionStateSkipsWhenNil() {
        let sut = addAction.lift(action: \GA.local, state: \GS.local)
        var state = GS()
        sut.reduce(GA(local: nil))(&state)
        XCTAssertEqual(state.local, 0)
    }

    // MARK: - KeyPath: state only

    func testLiftKeyPathStateOnly() {
        let sut = addAction.lift(state: \GS.local)
        var state = GS()
        sut.reduce(7)(&state)
        XCTAssertEqual(state.local, 7)
        XCTAssertEqual(state.other, 99)
    }

    // MARK: - KeyPath: action only

    func testLiftKeyPathActionOnly() {
        let sut = addAction.lift(action: \GA.local)
        var state = 0
        sut.reduce(GA(local: 4))(&state)
        XCTAssertEqual(state, 4)
        sut.reduce(GA(local: nil))(&state)
        XCTAssertEqual(state, 4)
    }

    // MARK: - Closure-based

    func testLiftClosureAppliesWhenMatched() {
        let sut = addAction.lift(
            actionGetter: { (ga: GA) in ga.local },
            stateGetter: { (gs: GS) in gs.local },
            stateSetter: { gs, local in gs.local = local }
        )
        var state = GS()
        sut.reduce(GA(local: 3))(&state)
        XCTAssertEqual(state.local, 3)
    }

    func testLiftClosureSkipsWhenNil() {
        let sut = addAction.lift(
            actionGetter: { (ga: GA) in ga.local },
            stateGetter: { (gs: GS) in gs.local },
            stateSetter: { gs, local in gs.local = local }
        )
        var state = GS()
        sut.reduce(GA(local: nil))(&state)
        XCTAssertEqual(state.local, 0)
    }

    // MARK: - Prism + Lens

    func testLiftPrismLensAppliesWhenMatched() {
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let stateLens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = addAction.lift(action: actionPrism, state: stateLens)
        var state = GS()
        sut.reduce(GA(local: 6))(&state)
        XCTAssertEqual(state.local, 6)
        XCTAssertEqual(state.other, 99)
    }

    func testLiftPrismLensSkipsWhenNil() {
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let stateLens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = addAction.lift(action: actionPrism, state: stateLens)
        var state = GS()
        sut.reduce(GA(local: nil))(&state)
        XCTAssertEqual(state.local, 0)
    }

    // MARK: - Prism only (action)

    func testLiftPrismActionOnly() {
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let sut = addAction.lift(action: actionPrism)
        var state = 0
        sut.reduce(GA(local: 5))(&state)
        XCTAssertEqual(state, 5)
        sut.reduce(GA(local: nil))(&state)
        XCTAssertEqual(state, 5)
    }

    // MARK: - Lens only (state)

    func testLiftLensStateOnly() {
        let stateLens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = addAction.lift(state: stateLens)
        var state = GS()
        sut.reduce(8)(&state)
        XCTAssertEqual(state.local, 8)
        XCTAssertEqual(state.other, 99)
    }

    // MARK: - Prism (partial state)

    func testLiftStatePrismRunsWhenMatched() {
        enum LS { case active(Int); case inactive }
        let statePrism = Prism<LS, Int>(
            preview: { if case .active(let v) = $0 { return v } else { return nil } },
            review: { .active($0) }
        )
        let sut = addAction.lift(state: statePrism)
        var state = LS.active(0)
        sut.reduce(5)(&state)
        if case .active(let v) = state { XCTAssertEqual(v, 5) } else { XCTFail("Expected .active") }
    }

    func testLiftStatePrismSkipsWhenNotMatched() {
        enum LS { case active(Int); case inactive }
        let statePrism = Prism<LS, Int>(
            preview: { if case .active(let v) = $0 { return v } else { return nil } },
            review: { .active($0) }
        )
        let sut = addAction.lift(state: statePrism)
        var state = LS.inactive
        sut.reduce(5)(&state)
        if case .inactive = state {} else { XCTFail("Expected .inactive") }
    }

    // MARK: - Prism + Prism

    func testLiftActionPrismStatePrismRunsWhenBothMatch() {
        enum LS { case active(Int); case inactive }
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let statePrism = Prism<LS, Int>(
            preview: { if case .active(let v) = $0 { return v } else { return nil } },
            review: { .active($0) }
        )
        let sut = addAction.lift(action: actionPrism, state: statePrism)
        var state = LS.active(0)
        sut.reduce(GA(local: 3))(&state)
        if case .active(let v) = state { XCTAssertEqual(v, 3) } else { XCTFail() }
    }

    func testLiftActionPrismStatePrismSkipsWhenActionNil() {
        enum LS { case active(Int); case inactive }
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let statePrism = Prism<LS, Int>(
            preview: { if case .active(let v) = $0 { return v } else { return nil } },
            review: { .active($0) }
        )
        let sut = addAction.lift(action: actionPrism, state: statePrism)
        var state = LS.active(0)
        sut.reduce(GA(local: nil))(&state)
        if case .active(let v) = state { XCTAssertEqual(v, 0) } else { XCTFail() }
    }

    // MARK: - AffineTraversal (state)

    func testLiftAffineTraversalRunsWhenFocusExists() {
        struct Container { var nums: [Int] }
        let traversal = AffineTraversal<Container, Int>(
            preview: { $0.nums.first },
            set: { c, v in
                var copy = c
                if !copy.nums.isEmpty { copy.nums[0] = v }
                return copy
            }
        )
        let sut = addAction.lift(state: traversal)
        var state = Container(nums: [0, 99])
        sut.reduce(5)(&state)
        XCTAssertEqual(state.nums, [5, 99])
    }

    func testLiftAffineTraversalSkipsWhenFocusMissing() {
        struct Container { var nums: [Int] }
        let traversal = AffineTraversal<Container, Int>(
            preview: { $0.nums.first },
            set: { c, v in
                var copy = c
                if !copy.nums.isEmpty { copy.nums[0] = v }
                return copy
            }
        )
        let sut = addAction.lift(state: traversal)
        var state = Container(nums: [])
        sut.reduce(5)(&state)
        XCTAssertTrue(state.nums.isEmpty)
    }

    // MARK: - Prism + AffineTraversal

    func testLiftPrismAffineTraversalRunsWhenBothMatch() {
        struct Container { var nums: [Int] }
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let traversal = AffineTraversal<Container, Int>(
            preview: { $0.nums.first },
            set: { c, v in
                var copy = c
                if !copy.nums.isEmpty { copy.nums[0] = v }
                return copy
            }
        )
        let sut = addAction.lift(action: actionPrism, state: traversal)
        var state = Container(nums: [0])
        sut.reduce(GA(local: 3))(&state)
        XCTAssertEqual(state.nums, [3])
    }
}
