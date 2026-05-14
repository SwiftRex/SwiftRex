import XCTest
import CoreFP
@testable import SwiftRex

final class ReducerLiftTests: XCTestCase {
    // MARK: - Helpers

    private struct GA { var local: Int?; var other: String? }
    private struct GS { var local: Int = 0; var other: Int = 99 }

    private let addAction = Reducer<Int, Int>.reduce { action, state in state += action }

    // MARK: - WritableKeyPath: state only

    func testLiftKeyPathStateOnly() {
        let sut = addAction.lift(state: \GS.local)
        var state = GS()
        sut.reduce(7)(&state)
        XCTAssertEqual(state.local, 7)
        XCTAssertEqual(state.other, 99)
    }

    // MARK: - Closure: action only

    func testLiftActionGetterOnlyAppliesWhenMatched() {
        let sut = addAction.lift(actionGetter: { (ga: GA) in ga.local })
        var state = 0
        sut.reduce(GA(local: 4))(&state)
        XCTAssertEqual(state, 4)
    }

    func testLiftActionGetterOnlySkipsWhenNil() {
        let sut = addAction.lift(actionGetter: { (ga: GA) in ga.local })
        var state = 0
        sut.reduce(GA(local: nil))(&state)
        XCTAssertEqual(state, 0)
    }

    // MARK: - Closure: state only

    func testLiftStateGetterSetterOnly() {
        let sut = addAction.lift(
            stateGetter: { (gs: GS) in gs.local },
            stateSetter: { gs, local in gs.local = local }
        )
        var state = GS()
        sut.reduce(9)(&state)
        XCTAssertEqual(state.local, 9)
        XCTAssertEqual(state.other, 99)
    }

    // MARK: - Prism + WritableKeyPath

    func testLiftPrismWKPAppliesWhenMatched() {
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let sut = addAction.lift(action: actionPrism, state: \GS.local)
        var state = GS()
        sut.reduce(GA(local: 5))(&state)
        XCTAssertEqual(state.local, 5)
        XCTAssertEqual(state.other, 99)
    }

    func testLiftPrismWKPSkipsWhenNil() {
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let sut = addAction.lift(action: actionPrism, state: \GS.local)
        var state = GS()
        sut.reduce(GA(local: nil))(&state)
        XCTAssertEqual(state.local, 0)
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

    func testLiftPrismAffineTraversalSkipsWhenActionNil() {
        struct Container { var nums: [Int] }
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let traversal = AffineTraversal<Container, Int>(
            preview: { $0.nums.first },
            set: { c, v in var copy = c; if !copy.nums.isEmpty { copy.nums[0] = v }; return copy }
        )
        let sut = addAction.lift(action: actionPrism, state: traversal)
        var state = Container(nums: [10])
        sut.reduce(GA(local: nil))(&state)
        XCTAssertEqual(state.nums, [10])
    }

    func testLiftPrismAffineTraversalSkipsWhenFocusMissing() {
        struct Container { var nums: [Int] }
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let traversal = AffineTraversal<Container, Int>(
            preview: { $0.nums.first },
            set: { c, v in var copy = c; if !copy.nums.isEmpty { copy.nums[0] = v }; return copy }
        )
        let sut = addAction.lift(action: actionPrism, state: traversal)
        var state = Container(nums: [])
        sut.reduce(GA(local: 5))(&state)
        XCTAssertTrue(state.nums.isEmpty)
    }

    // MARK: - Prism + Prism (state miss)

    func testLiftActionPrismStatePrismSkipsWhenStateNotMatched() {
        enum LS { case active(Int); case inactive }
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let statePrism = Prism<LS, Int>(
            preview: { if case .active(let v) = $0 { return v } else { return nil } },
            review: { .active($0) }
        )
        let sut = addAction.lift(action: actionPrism, state: statePrism)
        var state = LS.inactive
        sut.reduce(GA(local: 7))(&state)
        if case .inactive = state {} else { XCTFail("Expected .inactive") }
    }

    // MARK: - Lens setMut-based (via closure overload)

    func testLiftClosureSetMutKeepsOtherFieldsUntouched() {
        // stateSetter is (inout GS, S) -> Void — drives Lens(get:setMut:) internally
        let sut = addAction.lift(
            actionGetter: { (ga: GA) in ga.local },
            stateGetter: { (gs: GS) in gs.local },
            stateSetter: { gs, local in gs.local = local }
        )
        var state = GS(local: 0, other: 99)
        sut.reduce(GA(local: 10))(&state)
        XCTAssertEqual(state.local, 10)
        XCTAssertEqual(state.other, 99)
    }

    // MARK: - AffineTraversal (action only)

    func testLiftATActionOnlyAppliesWhenMatched() {
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let sut = addAction.lift(action: at)
        var state = 0
        sut.reduce(GA(local: 6))(&state)
        XCTAssertEqual(state, 6)
    }

    func testLiftATActionOnlySkipsWhenNil() {
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let sut = addAction.lift(action: at)
        var state = 0
        sut.reduce(GA(local: nil))(&state)
        XCTAssertEqual(state, 0)
    }

    // MARK: - AffineTraversal (action) + WritableKeyPath (state)

    func testLiftATActionWKPStateAppliesWhenMatched() {
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let sut = addAction.lift(action: at, state: \GS.local)
        var state = GS()
        sut.reduce(GA(local: 3))(&state)
        XCTAssertEqual(state.local, 3)
        XCTAssertEqual(state.other, 99)
    }

    func testLiftATActionWKPStateSkipsWhenNil() {
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let sut = addAction.lift(action: at, state: \GS.local)
        var state = GS()
        sut.reduce(GA(local: nil))(&state)
        XCTAssertEqual(state.local, 0)
    }

    // MARK: - AffineTraversal (action) + Lens (state)

    func testLiftATActionLensStateAppliesWhenMatched() {
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let stateLens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = addAction.lift(action: at, state: stateLens)
        var state = GS()
        sut.reduce(GA(local: 4))(&state)
        XCTAssertEqual(state.local, 4)
    }

    // MARK: - AffineTraversal (action) + Prism (state)

    func testLiftATActionPrismStateRunsWhenBothMatch() {
        enum LS { case active(Int); case inactive }
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let statePrism = Prism<LS, Int>(
            preview: { if case .active(let v) = $0 { return v } else { return nil } },
            review: { .active($0) }
        )
        let sut = addAction.lift(action: at, state: statePrism)
        var state = LS.active(0)
        sut.reduce(GA(local: 5))(&state)
        if case .active(let v) = state { XCTAssertEqual(v, 5) } else { XCTFail() }
    }

    // MARK: - AffineTraversal (action) + AffineTraversal (state)

    func testLiftATActionATStateRunsWhenBothMatch() {
        struct Container { var nums: [Int] }
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let stateAT = AffineTraversal<Container, Int>(
            preview: { $0.nums.first },
            set: { c, v in var copy = c; if !copy.nums.isEmpty { copy.nums[0] = v }; return copy }
        )
        let sut = addAction.lift(action: at, state: stateAT)
        var state = Container(nums: [0, 99])
        sut.reduce(GA(local: 7))(&state)
        XCTAssertEqual(state.nums, [7, 99])
    }

    // MARK: - Composed optic via .compose()

    func testLiftComposedLensChain() {
        struct Inner { var count: Int }
        struct Outer { var inner: Inner; var tag: String }
        let countReducer = Reducer<Int, Int>.reduce { delta, n in n += delta }
        let composed = lens(\Outer.inner).compose(lens(\Inner.count))
        let sut = countReducer.lift(state: composed)
        var state = Outer(inner: Inner(count: 0), tag: "x")
        sut.reduce(5)(&state)
        XCTAssertEqual(state.inner.count, 5)
        XCTAssertEqual(state.tag, "x")
    }
}
