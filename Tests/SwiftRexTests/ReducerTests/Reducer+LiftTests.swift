import CoreFP
@testable import SwiftRex
import Testing

@Suite
struct ReducerLiftTests {
    // MARK: - Helpers

    private struct GA { var local: Int?; var other: String? }
    private struct GS { var local: Int = 0; var other: Int = 99 }

    private let addAction = Reducer<Int, Int>.reduce { action, state in state += action }

    // MARK: - WritableKeyPath: state only

    @Test func liftKeyPathStateOnly() {
        let sut = addAction.lift(state: \GS.local)
        var state = GS()
        sut.reduce(7)(&state)
        #expect(state.local == 7)
        #expect(state.other == 99)
    }

    // MARK: - Closure: action only

    @Test func liftActionGetterOnlyAppliesWhenMatched() {
        let sut = addAction.lift(actionGetter: { (ga: GA) in ga.local })
        var state = 0
        sut.reduce(GA(local: 4))(&state)
        #expect(state == 4)
    }

    @Test func liftActionGetterOnlySkipsWhenNil() {
        let sut = addAction.lift(actionGetter: { (ga: GA) in ga.local })
        var state = 0
        sut.reduce(GA(local: nil))(&state)
        #expect(state == 0)
    }

    // MARK: - Closure: state only

    @Test func liftStateGetterSetterOnly() {
        let sut = addAction.lift(
            stateGetter: { (gs: GS) in gs.local },
            stateSetter: { gs, local in gs.local = local }
        )
        var state = GS()
        sut.reduce(9)(&state)
        #expect(state.local == 9)
        #expect(state.other == 99)
    }

    // MARK: - Prism + WritableKeyPath

    @Test func liftPrismWKPAppliesWhenMatched() {
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let sut = addAction.lift(action: actionPrism, state: \GS.local)
        var state = GS()
        sut.reduce(GA(local: 5))(&state)
        #expect(state.local == 5)
        #expect(state.other == 99)
    }

    @Test func liftPrismWKPSkipsWhenNil() {
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let sut = addAction.lift(action: actionPrism, state: \GS.local)
        var state = GS()
        sut.reduce(GA(local: nil))(&state)
        #expect(state.local == 0)
    }

    // MARK: - Closure-based

    @Test func liftClosureAppliesWhenMatched() {
        let sut = addAction.lift(
            actionGetter: { (ga: GA) in ga.local },
            stateGetter: { (gs: GS) in gs.local },
            stateSetter: { gs, local in gs.local = local }
        )
        var state = GS()
        sut.reduce(GA(local: 3))(&state)
        #expect(state.local == 3)
    }

    @Test func liftClosureSkipsWhenNil() {
        let sut = addAction.lift(
            actionGetter: { (ga: GA) in ga.local },
            stateGetter: { (gs: GS) in gs.local },
            stateSetter: { gs, local in gs.local = local }
        )
        var state = GS()
        sut.reduce(GA(local: nil))(&state)
        #expect(state.local == 0)
    }

    // MARK: - Prism + Lens

    @Test func liftPrismLensAppliesWhenMatched() {
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let stateLens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = addAction.lift(action: actionPrism, state: stateLens)
        var state = GS()
        sut.reduce(GA(local: 6))(&state)
        #expect(state.local == 6)
        #expect(state.other == 99)
    }

    @Test func liftPrismLensSkipsWhenNil() {
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let stateLens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = addAction.lift(action: actionPrism, state: stateLens)
        var state = GS()
        sut.reduce(GA(local: nil))(&state)
        #expect(state.local == 0)
    }

    // MARK: - Prism only (action)

    @Test func liftPrismActionOnly() {
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let sut = addAction.lift(action: actionPrism)
        var state = 0
        sut.reduce(GA(local: 5))(&state)
        #expect(state == 5)
        sut.reduce(GA(local: nil))(&state)
        #expect(state == 5)
    }

    // MARK: - Lens only (state)

    @Test func liftLensStateOnly() {
        let stateLens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = addAction.lift(state: stateLens)
        var state = GS()
        sut.reduce(8)(&state)
        #expect(state.local == 8)
        #expect(state.other == 99)
    }

    // MARK: - Prism (partial state)

    @Test func liftStatePrismRunsWhenMatched() {
        enum LS { case active(Int); case inactive }
        let statePrism = Prism<LS, Int>(
            preview: { if case .active(let v) = $0 { return v } else { return nil } },
            review: { .active($0) }
        )
        let sut = addAction.lift(state: statePrism)
        var state = LS.active(0)
        sut.reduce(5)(&state)
        if case .active(let v) = state { #expect(v == 5) } else { Issue.record("Expected .active") }
    }

    @Test func liftStatePrismSkipsWhenNotMatched() {
        enum LS { case active(Int); case inactive }
        let statePrism = Prism<LS, Int>(
            preview: { if case .active(let v) = $0 { return v } else { return nil } },
            review: { .active($0) }
        )
        let sut = addAction.lift(state: statePrism)
        var state = LS.inactive
        sut.reduce(5)(&state)
        if case .inactive = state {} else { Issue.record("Expected .inactive") }
    }

    // MARK: - Prism + Prism

    @Test func liftActionPrismStatePrismRunsWhenBothMatch() {
        enum LS { case active(Int); case inactive }
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let statePrism = Prism<LS, Int>(
            preview: { if case .active(let v) = $0 { return v } else { return nil } },
            review: { .active($0) }
        )
        let sut = addAction.lift(action: actionPrism, state: statePrism)
        var state = LS.active(0)
        sut.reduce(GA(local: 3))(&state)
        if case .active(let v) = state { #expect(v == 3) } else { Issue.record("Unexpected state") }
    }

    @Test func liftActionPrismStatePrismSkipsWhenActionNil() {
        enum LS { case active(Int); case inactive }
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let statePrism = Prism<LS, Int>(
            preview: { if case .active(let v) = $0 { return v } else { return nil } },
            review: { .active($0) }
        )
        let sut = addAction.lift(action: actionPrism, state: statePrism)
        var state = LS.active(0)
        sut.reduce(GA(local: nil))(&state)
        if case .active(let v) = state { #expect(v == 0) } else { Issue.record("Unexpected state") }
    }

    // MARK: - AffineTraversal (state)

    @Test func liftAffineTraversalRunsWhenFocusExists() {
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
        #expect(state.nums == [5, 99])
    }

    @Test func liftAffineTraversalSkipsWhenFocusMissing() {
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
        #expect(state.nums.isEmpty)
    }

    // MARK: - Prism + AffineTraversal

    @Test func liftPrismAffineTraversalRunsWhenBothMatch() {
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
        #expect(state.nums == [3])
    }

    @Test func liftPrismAffineTraversalSkipsWhenActionNil() {
        struct Container { var nums: [Int] }
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let traversal = AffineTraversal<Container, Int>(
            preview: { $0.nums.first },
            set: { c, v in var copy = c; if !copy.nums.isEmpty { copy.nums[0] = v }; return copy }
        )
        let sut = addAction.lift(action: actionPrism, state: traversal)
        var state = Container(nums: [10])
        sut.reduce(GA(local: nil))(&state)
        #expect(state.nums == [10])
    }

    @Test func liftPrismAffineTraversalSkipsWhenFocusMissing() {
        struct Container { var nums: [Int] }
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let traversal = AffineTraversal<Container, Int>(
            preview: { $0.nums.first },
            set: { c, v in var copy = c; if !copy.nums.isEmpty { copy.nums[0] = v }; return copy }
        )
        let sut = addAction.lift(action: actionPrism, state: traversal)
        var state = Container(nums: [])
        sut.reduce(GA(local: 5))(&state)
        #expect(state.nums.isEmpty)
    }

    // MARK: - Prism + Prism (state miss)

    @Test func liftActionPrismStatePrismSkipsWhenStateNotMatched() {
        enum LS { case active(Int); case inactive }
        let actionPrism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0) })
        let statePrism = Prism<LS, Int>(
            preview: { if case .active(let v) = $0 { return v } else { return nil } },
            review: { .active($0) }
        )
        let sut = addAction.lift(action: actionPrism, state: statePrism)
        var state = LS.inactive
        sut.reduce(GA(local: 7))(&state)
        if case .inactive = state {} else { Issue.record("Expected .inactive") }
    }

    // MARK: - Lens setMut-based (via closure overload)

    @Test func liftClosureSetMutKeepsOtherFieldsUntouched() {
        // stateSetter is (inout GS, S) -> Void — drives Lens(get:setMut:) internally
        let sut = addAction.lift(
            actionGetter: { (ga: GA) in ga.local },
            stateGetter: { (gs: GS) in gs.local },
            stateSetter: { gs, local in gs.local = local }
        )
        var state = GS(local: 0, other: 99)
        sut.reduce(GA(local: 10))(&state)
        #expect(state.local == 10)
        #expect(state.other == 99)
    }

    // MARK: - AffineTraversal (action only)

    @Test func liftATActionOnlyAppliesWhenMatched() {
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let sut = addAction.lift(action: at)
        var state = 0
        sut.reduce(GA(local: 6))(&state)
        #expect(state == 6)
    }

    @Test func liftATActionOnlySkipsWhenNil() {
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let sut = addAction.lift(action: at)
        var state = 0
        sut.reduce(GA(local: nil))(&state)
        #expect(state == 0)
    }

    // MARK: - AffineTraversal (action) + WritableKeyPath (state)

    @Test func liftATActionWKPStateAppliesWhenMatched() {
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let sut = addAction.lift(action: at, state: \GS.local)
        var state = GS()
        sut.reduce(GA(local: 3))(&state)
        #expect(state.local == 3)
        #expect(state.other == 99)
    }

    @Test func liftATActionWKPStateSkipsWhenNil() {
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let sut = addAction.lift(action: at, state: \GS.local)
        var state = GS()
        sut.reduce(GA(local: nil))(&state)
        #expect(state.local == 0)
    }

    // MARK: - AffineTraversal (action) + Lens (state)

    @Test func liftATActionLensStateAppliesWhenMatched() {
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let stateLens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = addAction.lift(action: at, state: stateLens)
        var state = GS()
        sut.reduce(GA(local: 4))(&state)
        #expect(state.local == 4)
    }

    // MARK: - AffineTraversal (action) + Prism (state)

    @Test func liftATActionPrismStateRunsWhenBothMatch() {
        enum LS { case active(Int); case inactive }
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let statePrism = Prism<LS, Int>(
            preview: { if case .active(let v) = $0 { return v } else { return nil } },
            review: { .active($0) }
        )
        let sut = addAction.lift(action: at, state: statePrism)
        var state = LS.active(0)
        sut.reduce(GA(local: 5))(&state)
        if case .active(let v) = state { #expect(v == 5) } else { Issue.record("Unexpected state") }
    }

    // MARK: - AffineTraversal (action) + AffineTraversal (state)

    @Test func liftATActionATStateRunsWhenBothMatch() {
        struct Container { var nums: [Int] }
        let at = AffineTraversal<GA, Int>(preview: { $0.local }, set: { ga, v in GA(local: v, other: ga.other) })
        let stateAT = AffineTraversal<Container, Int>(
            preview: { $0.nums.first },
            set: { c, v in var copy = c; if !copy.nums.isEmpty { copy.nums[0] = v }; return copy }
        )
        let sut = addAction.lift(action: at, state: stateAT)
        var state = Container(nums: [0, 99])
        sut.reduce(GA(local: 7))(&state)
        #expect(state.nums == [7, 99])
    }

    // MARK: - Composed optic via .compose()

    @Test func liftComposedLensChain() {
        struct Inner { var count: Int }
        struct Outer { var inner: Inner; var tag: String }
        let countReducer = Reducer<Int, Int>.reduce { delta, n in n += delta }
        let composed = lens(\Outer.inner).compose(lens(\Inner.count))
        let sut = countReducer.lift(state: composed)
        var state = Outer(inner: Inner(count: 0), tag: "x")
        sut.reduce(5)(&state)
        #expect(state.inner.count == 5)
        #expect(state.tag == "x")
    }
}
