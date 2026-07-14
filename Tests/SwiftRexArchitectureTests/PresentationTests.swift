// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
import CoreFP
@testable import SwiftRex
import SwiftRexSwiftUI
import Testing

@Suite("Presentation")
struct PresentationTests {
    @Test func wrappedAndIsPresented() {
        #expect(Presentation.presented(1).wrapped == 1)
        #expect(Presentation.dismissing(last: 2).wrapped == 2)   // still renders the last value
        #expect(Presentation<Int>.dismissed.wrapped == nil)
        #expect(Presentation.presented(1).isPresented)
        #expect(!Presentation.dismissing(last: 1).isPresented)   // false the moment dismissal begins
        #expect(!Presentation<Int>.dismissed.isPresented)
    }

    @Test func mapPreservesStage() {
        #expect(Presentation.presented(2).map { $0 * 10 } == .presented(20))
        #expect(Presentation.dismissing(last: 2).map { $0 * 10 } == .dismissing(last: 20))
        #expect(Presentation<Int>.dismissed.map { $0 * 10 } == .dismissed)
    }

    @Test func dismissWalksStagesAndIsIdempotent() {
        #expect(Presentation.presented(1).dismiss() == .dismissing(last: 1))
        #expect(Presentation.dismissing(last: 1).dismiss() == .dismissed)
        #expect(Presentation<Int>.dismissed.dismiss() == .dismissed)
    }

    @Test func writableWrappedUpdatesPayloadPreservingStage() {
        var p = Presentation.presented(1); p.wrapped = 5
        #expect(p == .presented(5))
        var d = Presentation.dismissing(last: 1); d.wrapped = 9
        #expect(d == .dismissing(last: 9))
        var gone = Presentation<Int>.dismissed; gone.wrapped = 3
        #expect(gone == .dismissed)          // cannot materialise a payload; ignored
    }
}

// MARK: - liftPresentation

private enum ChildAction: Equatable, Sendable { case inc }
private struct ChildState: Equatable, Sendable { var n = 0 }

private enum GlobalAct: Equatable, Sendable {
    case detail(PresentationAction<ChildAction>)
    case other
}

private struct GlobalSt: Equatable, Sendable {
    var detail: Presentation<ChildState> = .dismissed
}

@Suite("Behavior.liftPresentation")
@MainActor
struct LiftPresentationTests {
    // Start already presented — presenting is a parent-reducer concern (`slot = .presented(_)`), not an
    // action, so `PresentationAction` never carries the child State.
    private func makeStore() -> Store<GlobalAct, GlobalSt, Void> {
        let child = Behavior<ChildAction, ChildState, Void>.reduce { action, state in
            switch action {
            case .inc: state.n += 1
            }
        }
        let detailPrism = Prism<GlobalAct, PresentationAction<ChildAction>>(
            preview: { if case let .detail(inner) = $0 { inner } else { nil } },
            review: GlobalAct.detail
        )
        let behavior = child.liftPresentation(action: detailPrism, state: \GlobalSt.detail, environment: { (_: Void) in () })
        return Store(initial: GlobalSt(detail: .presented(ChildState(n: 5))), behavior: behavior, environment: ())
    }

    @Test func childMutatesWhilePresentedAndDismissingThenDismissWalks() {
        let store = makeStore()
        #expect(store.state.detail == .presented(ChildState(n: 5)))

        store.dispatch(.detail(.child(.inc)))            // child runs while presented
        #expect(store.state.detail == .presented(ChildState(n: 6)))

        store.dispatch(.detail(.dismiss))                // presented -> dismissing(last:)
        #expect(store.state.detail == .dismissing(last: ChildState(n: 6)))

        store.dispatch(.detail(.child(.inc)))            // child still runs while dismissing (late effect)
        #expect(store.state.detail == .dismissing(last: ChildState(n: 7)))

        store.dispatch(.detail(.dismiss))                // dismissing -> dismissed
        #expect(store.state.detail == .dismissed)

        store.dispatch(.detail(.child(.inc)))            // no wrapped state -> no-op
        #expect(store.state.detail == .dismissed)
    }
}

#endif
