// SPDX-License-Identifier: Apache-2.0

// The Relay-scope surface that replaced the pre-scope overloads: enum-case state lanes, key-path broadcast,
// `@Prisms` navigation enums, the scope form of `liftPresentation`, and building a feature's view from an
// optional or presented slot of a declared scope.

#if canImport(AppKit) && canImport(SwiftUI) && canImport(Combine)
    import CoreFP
    import SwiftRex
    import SwiftRexArchitecture
    import SwiftUI
    import Testing

    // MARK: - Domain

    struct SSCounter: Sendable, Equatable { var n = 0 }

    enum SSCounterAction: Sendable, Equatable { case inc }

    @Prisms
    enum SSScreen: Sendable, Equatable {
        case loading
        case loaded(SSCounter)
    }

    struct SSRow: Sendable, Equatable, Identifiable { var id: Int; var n = 0 }

    @Prisms
    enum SSAction: Sendable, Equatable {
        case counter(SSCounterAction)
        case tick(SSCounterAction)
        case row(ElementAction<Int, SSCounterAction>)
        case nav(StackNavigation<Int>)
        case editor(PresentationAction<SSCounterAction>)
        case detail(SSCounterAction)
    }

    struct SSState: Sendable, Equatable {
        var rows: [SSRow] = [SSRow(id: 1), SSRow(id: 2)]
        var path: [Int] = []
        var editor: Presentation<SSCounter> = .dismissed
        var detail: SSCounter?
    }

    private let increment = Behavior<SSCounterAction, SSCounter, Void>.reduce { action, state in
        switch action {
        case .inc: state.n += 1
        }
    }

    private let incrementRow = Behavior<SSCounterAction, SSRow, Void>.reduce { action, state in
        switch action {
        case .inc: state.n += 1
        }
    }

    // MARK: - State lanes into an enum case

    @Suite("Relay.Scope — enum-case state lanes")
    @MainActor
    struct EnumCaseStateLaneTests {
        @Test func aCaseKeyPathLiftsIntoTheCase() {
            let behavior: Behavior<SSAction, SSScreen, Void> = increment.lift(.action(\.counter).state(\.loaded).environment { (env: Void) in env })
            let store = Store(initial: SSScreen.loaded(SSCounter()), behavior: behavior, environment: ())
            store.dispatch(.counter(.inc))
            #expect(store.currentState == .loaded(SSCounter(n: 1)))
        }

        @Test func aMissingCaseIsSkipped() {
            let behavior: Behavior<SSAction, SSScreen, Void> = increment.lift(.action(\.counter).state(\.loaded).environment { (env: Void) in env })
            let store = Store(initial: SSScreen.loading, behavior: behavior, environment: ())
            store.dispatch(.counter(.inc))
            #expect(store.currentState == .loading)
        }

        @Test func aPrismAndAnAffineTraversalLiftTheSameWay() {
            let prism = Prism<SSScreen, SSCounter>(\.loaded)
            let viaPrism: Behavior<SSAction, SSScreen, Void> = increment.lift(.action(\.counter).state(prism).environment { (env: Void) in env })
            let viaAffine: Behavior<SSAction, SSScreen, Void> = increment.lift(
                .action(\.counter)
                    .state(AffineTraversal(preview: prism.preview, set: { _, part in prism.review(part) }))
                    .environment { (env: Void) in env }
            )
            for behavior in [viaPrism, viaAffine] {
                let store = Store(initial: SSScreen.loaded(SSCounter(n: 4)), behavior: behavior, environment: ())
                store.dispatch(.counter(.inc))
                #expect(store.currentState == .loaded(SSCounter(n: 5)))
            }
        }

        @Test func aPlainKeyPathStillResolvesToTheKeyPathLane() {
            // `.state(\.self)` must not become ambiguous with the case-key-path entry.
            let behavior: Behavior<SSCounterAction, SSCounter, Void> = increment.lift(
                .action(\.self).state(\.self).environment { (env: Void) in env }
            )
            let store = Store(initial: SSCounter(), behavior: behavior, environment: ())
            store.dispatch(.inc)
            #expect(store.currentState.n == 1)
        }
    }

    // MARK: - Broadcast from case key paths

    @Suite("Relay.Scope — key-path broadcast")
    @MainActor
    struct KeyPathBroadcastTests {
        @Test func everyRowGetsTheBroadcastAction() {
            let behavior: Behavior<SSAction, SSState, Void> = incrementRow.liftEach(
                .action(broadcast: \.tick, into: \.row).state(\.rows).environment { (env: Void) in env }
            )
            let store = Store(initial: SSState(), behavior: behavior, environment: ())
            store.dispatch(.tick(.inc))
            #expect(store.currentState.rows.map(\.n) == [1, 1])
        }
    }

    // MARK: - Navigation enums have prisms

    @Suite("Navigation enums — @Prisms")
    @MainActor
    struct NavigationPrismsTests {
        @Test func aNavigationCaseIsReachableByKeyPath() {
            let setPath = Prism<SSAction, [Int]>(\.nav.setPath)
            #expect(setPath.preview(.nav(.setPath([1, 2]))) == [1, 2])
            #expect(setPath.review([3]) == .nav(.setPath([3])))
            let behavior = Behavior<SSAction, SSState, Void>.navigationStack(\.path, action: \.nav)
            let store = Store(initial: SSState(), behavior: behavior, environment: ())
            store.dispatch(setPath.review([7]))
            #expect(store.currentState.path == [7])
        }
    }

    // MARK: - liftPresentation through a scope

    @Suite("liftPresentation — scope form")
    @MainActor
    struct LiftPresentationScopeTests {
        @Test func theChildRunsWhilePresentedAndTheEdgesMoveTheSlot() {
            let behavior: Behavior<SSAction, SSState, Void> = increment.liftPresentation(
                .action(\.editor).state(\.editor).environment { (env: Void) in env }
            )
            var initial = SSState()
            initial.editor = .presented(SSCounter())
            let store = Store(initial: initial, behavior: behavior, environment: ())
            store.dispatch(.editor(.child(.inc)))
            #expect(store.currentState.editor == .presented(SSCounter(n: 1)))
            store.dispatch(.editor(.dismiss))
            #expect(store.currentState.editor == .dismissing(last: SSCounter(n: 1)))
            store.dispatch(.editor(.child(.inc)))                            // late child actions still land
            #expect(store.currentState.editor == .dismissing(last: SSCounter(n: 2)))
            store.dispatch(.editor(.dismissed))
            #expect(store.currentState.editor == .dismissed)
        }
    }

    // MARK: - A feature's view from an optional or presented slot

    enum SSCounterFeature: ViewFactory {
        typealias Action = SSCounterAction
        typealias State = SSCounter
        typealias Environment = Void

        @MainActor
        static func view(store: any StoreType<Action, State>, environment: Void) -> some View {
            SSCounterView(store: store)
        }
    }

    struct SSCounterView: View {
        @OwnedStore var viewStore: ViewStore<SSCounterAction, SSCounter>
        init(store: any StoreType<SSCounterAction, SSCounter>) { _viewStore = OwnedStore(wrappedValue: store.viewStore()) }
        var body: some View { Text("\(viewStore.state.n)") }
    }

    enum SSScopes {
        static let detail = ScopeOf<SSFeatureRig>.action(\.detail).state(\.detail).environment { _ in () }
        static let editor = ScopeOf<SSFeatureRig>.action(\.editor).state(\.editor).environment { _ in () }
    }

    enum SSFeatureRig: Rig {
        typealias Action = SSAction
        typealias State = SSState
        typealias Environment = Void
    }

    @Suite("Relay.Scope.view(of:from:world:) — optional and presented slots")
    @MainActor
    struct OptionalSlotViewTests {
        @Test func anOptionalSlotBuildsTheViewOnlyWhilePresent() {
            let store = Store(initial: SSState(), behavior: Behavior<SSAction, SSState, Void>.identity, environment: ())
            let viewStore = store.viewStore(.combine)
            #expect(SSScopes.detail.view(of: SSCounterFeature.self, from: viewStore, world: ()) == nil)
            let present = Store(initial: SSState(detail: SSCounter(n: 3)), behavior: Behavior<SSAction, SSState, Void>.identity, environment: ())
            #expect(SSScopes.detail.view(of: SSCounterFeature.self, from: present.viewStore(.combine), world: ()) != nil)
        }

        @Test func aPresentationSlotBuildsTheViewWhilePresentedOrDismissing() {
            for (slot, built) in [
                (Presentation<SSCounter>.dismissed, false),
                (.presented(SSCounter()), true),
                (.dismissing(last: SSCounter()), true)
            ] {
                let store = Store(initial: SSState(editor: slot), behavior: Behavior<SSAction, SSState, Void>.identity, environment: ())
                let view = SSScopes.editor.view(of: SSCounterFeature.self, from: store.viewStore(.combine), world: ())
                #expect((view != nil) == built)
            }
        }

        @Test func aDeclaredScopeTraverses() {
            let store = Store(initial: SSState(detail: SSCounter(n: 2)), behavior: Behavior<SSAction, SSState, Void>.identity, environment: ())
            let child = store.viewStore(.combine).traverse(SSScopes.detail)?.viewStore(.combine)
            #expect(child?.state.n == 2)
        }
    }
#endif
