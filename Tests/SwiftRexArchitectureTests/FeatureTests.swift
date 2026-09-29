// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    import DataStructure
    import Observation
    @testable import SwiftRex
    @testable import SwiftRexArchitecture
    import SwiftUI
    import Testing

    // MARK: - Projected fixture (ViewState/ViewAction)

//
    // A screen with feature-level ViewState/ViewAction (no ViewModel class). The view holds a
    // `viewStore`; @Feature generates `view()` handing it an `ObservableStore` over the projection.

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @BoundTo(HeroDetailsFeature.self)
    private struct HeroDetailsView: View {
        // @BoundTo injects: let viewStore: ViewStore<HeroDetailsFeature.ViewAction, HeroDetailsFeature.ViewState>
        var body: Never { fatalError("test stub") }
    }

    @Feature
    private enum HeroDetailsFeature {
        struct State: Sendable {
            var codename: String = "Kryptonian"
            var aliases: [String] = ["Superman", "Man of Steel"]
            var powers: [String] = ["flight", "heat vision"]
            var threatIndex: Int = 1
            var isRetired: Bool = false
        }

        enum Action: Sendable, Equatable {
            case savePowers([String])
            case setThreatIndex(Int)
            case toggleRetirement
        }

        struct Environment: Sendable {}

        struct ViewState: Sendable, Equatable {
            var displayName: String // aliases.first ?? codename
            var powersText: String // joined for TextField binding
            var threatIndex: Int
            var isRetired: Bool
        }

        enum ViewAction: Sendable {
            case editedPowers(String) // raw comma-separated TextField content
            case selectedThreat(Int)
            case tappedRetirement
        }

        static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { _ in
            { s in
                .init(
                    displayName: s.aliases.first ?? s.codename,
                    powersText: s.powers.joined(separator: ", "),
                    threatIndex: s.threatIndex,
                    isRetired: s.isRetired
                )
            }
        }

        static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action> { _ in
            { va in
                switch va {
                case let .editedPowers(raw):
                    .savePowers(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                case let .selectedThreat(index):
                    .setThreatIndex(index)
                case .tappedRetirement:
                    .toggleRetirement
                }
            }
        }

        static func initialState(with _: Void) -> State { .init() }

        static func behavior() -> Behavior<Action, State, Environment> {
            Reducer.reduce { (action: Action, state: inout State) in
                switch action {
                case let .savePowers(p): state.powers = p
                case let .setThreatIndex(i): state.threatIndex = i
                case .toggleRetirement: state.isRetired.toggle()
                }
            }.asBehavior()
        }

        typealias Content = HeroDetailsView
    }

    // MARK: - Combine fixture

//
    // .combine forces Combine signalling even on iOS 17+. The view's injected `let viewStore: ViewStore`
    // carries the Combine subscription itself, so @BoundTo needs no strategy.

    @BoundTo(WidgetFeature.self)
    private struct WidgetView: View {
        // @BoundTo injects: let viewStore: ViewStore<WidgetFeature.ViewAction, WidgetFeature.ViewState> — the same under every strategy
        var body: Never { fatalError("test stub") }
    }

    @Feature(strategy: .combine)
    private enum WidgetFeature {
        struct State: Sendable, Equatable { var count = 0 }
        enum Action: Sendable { case bump }
        struct Environment: Sendable {}
        struct ViewState: Sendable, Equatable { var label: String }
        enum ViewAction: Sendable { case tapped }

        static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { _ in
            { s in .init(label: "\(s.count)") }
        }

        static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action> { _ in
            { _ in .bump }
        }

        static func behavior() -> Behavior<Action, State, Environment> {
            Reducer.reduce { (action: Action, state: inout State) in
                switch action {
                case .bump: state.count += 1
                }
            }.asBehavior()
        }

        typealias Content = WidgetView
    }

    // MARK: - Direct fixtures (no ViewState/ViewAction — view sees State/Action)

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @BoundTo(DirectFeature.self)
    private struct DirectView: View {
        // @BoundTo injects: let viewStore: ViewStore<DirectFeature.ViewAction, DirectFeature.ViewState>,
        // and ViewState/ViewAction are macro-generated typealiases to State/Action.
        var body: Never { fatalError("test stub") }
    }

    @Feature
    private enum DirectFeature {
        struct State: Sendable, Equatable { var count = 0 }
        enum Action: Sendable { case inc }
        struct Environment: Sendable {}
        static func behavior() -> Behavior<Action, State, Environment> {
            Reducer.reduce { (a: Action, s: inout State) in
                switch a {
                case .inc: s.count += 1
                }
            }.asBehavior()
        }

        typealias Content = DirectView
        // No ViewState/ViewAction/mapState/mapAction — view() wraps the store directly.
    }

    // MARK: - L0 fixture (no Environment, no ViewState/ViewAction — the leanest feature)

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @BoundTo(MinimalFeature.self)
    private struct MinimalView: View {
        var body: Never { fatalError("test stub") }
    }

    @Feature
    private enum MinimalFeature {
        struct State: Sendable, Equatable { var count = 0 }
        enum Action: Sendable { case tick }
        // No Environment (macro aliases it to Void), no ViewState/ViewAction (aliased to State/Action).
        static func behavior() -> Behavior<Action, State, Environment> {
            Reducer.reduce { (a: Action, s: inout State) in
                switch a {
                case .tick: s.count += 1
                }
            }.asBehavior()
        }

        typealias Content = MinimalView
    }

    // MARK: - Helpers

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @MainActor
    private func makeHeroViewStore() -> ObservableStore<HeroDetailsFeature.ViewAction, HeroDetailsFeature.ViewState> {
        let store = Store(
            initial: HeroDetailsFeature.initialState(with: ()),
            behavior: HeroDetailsFeature.behavior(),
            environment: HeroDetailsFeature.Environment()
        )
        return store.projection(
            environment: .init(),
            action: HeroDetailsFeature.mapAction,
            state: HeroDetailsFeature.mapState
        ).observable()
    }

    // MARK: - mapState

    @Suite("HeroDetailsFeature.mapState")
    @MainActor
    struct MapStateTests {
        private func project(_ state: HeroDetailsFeature.State) -> HeroDetailsFeature.ViewState {
            HeroDetailsFeature.mapState(.init())(state)
        }

        @Test func usesFirstAliasAsDisplayName() {
            #expect(project(.init()).displayName == "Superman")
        }

        @Test func fallsBackToCodenameWhenNoAliases() {
            let vs = project(.init(codename: "Unknown", aliases: [], powers: [], threatIndex: 0, isRetired: false))
            #expect(vs.displayName == "Unknown")
        }

        @Test func joinsPowersWithComma() {
            #expect(project(.init()).powersText == "flight, heat vision")
        }

        @Test func equatableDeduplication() {
            let a = project(.init())
            let b = project(.init())
            #expect(a == b)
        }
    }

    // MARK: - mapAction

    @Suite("HeroDetailsFeature.mapAction")
    struct MapActionTests {
        @Test func parsesCommaSeparatedPowers() {
            #expect(HeroDetailsFeature.mapAction(.init())(.editedPowers("flight, strength, speed"))
                == .savePowers(["flight", "strength", "speed"]))
        }

        @Test func stripsWhitespaceWhenParsingPowers() {
            #expect(HeroDetailsFeature.mapAction(.init())(.editedPowers("  flight ,  heat vision  "))
                == .savePowers(["flight", "heat vision"]))
        }

        @Test func mapsThreatIndexWithNameChange() {
            #expect(HeroDetailsFeature.mapAction(.init())(.selectedThreat(2)) == .setThreatIndex(2))
        }
    }

    // MARK: - view store (end-to-end through the projection)

    @Suite("HeroDetailsFeature view store")
    @MainActor
    struct HeroViewStoreTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func seedsStateFromInitial() {
            let vs = makeHeroViewStore()
            #expect(vs.displayName == "Superman")
            #expect(vs.powersText == "flight, heat vision")
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func editingPowersParsesAndUpdatesState() async {
            let vs = makeHeroViewStore()
            vs.dispatch(.editedPowers("flying, invulnerability"))
            await Task.yield()
            #expect(vs.powersText == "flying, invulnerability")
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func togglingRetirementUpdatesState() async {
            let vs = makeHeroViewStore()
            vs.dispatch(.tappedRetirement)
            await Task.yield()
            #expect(vs.isRetired == true)
        }
    }

    // MARK: - generated view()

    @Suite("@Feature — generated view()")
    @MainActor
    struct GeneratedViewTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func projectedFeatureBuildsObservableStore() {
            // HeroDetailsView holds a `ViewStore`; this only compiles if view() handed it one.
            let store = Store(
                initial: HeroDetailsFeature.initialState(with: ()),
                behavior: HeroDetailsFeature.behavior(),
                environment: .init()
            )
            _ = HeroDetailsFeature.view(store: store, environment: .init())
        }

        // No @available — the combine path's view() is generated ungated, so this compiles and runs
        // without an iOS 17 requirement.
        @Test func combineFeatureBuildsWithoutIOS17() {
            let store = Store(
                initial: WidgetFeature.initialState(with: ()),
                behavior: WidgetFeature.behavior(),
                environment: .init()
            )
            _ = WidgetFeature.view(store: store, environment: .init())
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func directFeatureWrapsStoreWithoutProjection() {
            // DirectView holds ViewStore<Action, State> (via aliases); compiles only if view() wrapped
            // the store directly, no projection.
            let store = Store(initial: DirectFeature.initialState(with: ()), behavior: DirectFeature.behavior(), environment: .init())
            _ = DirectFeature.view(store: store, environment: .init())
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func minimalFeatureHasVoidEnvironmentAndDirectStore() {
            // No Environment (Void) and no view layer — the leanest feature still generates view().
            let store = Store(initial: MinimalFeature.initialState(with: ()), behavior: MinimalFeature.behavior(), environment: ())
            _ = MinimalFeature.view(store: store, environment: ())
        }
    }

    // MARK: - initialState synthesis (logic-only fixtures, no view layer)

    @Feature
    private enum CounterFeature {
        struct State: Sendable, Equatable { var count = 0 }
        enum Action: Sendable { case increment }
        struct Environment: Sendable {}
        static func behavior() -> Behavior<Action, State, Environment> {
            Reducer.reduce { (a: Action, s: inout State) in
                switch a {
                case .increment: s.count += 1
                }
            }.asBehavior()
        }
        // no `initialState` — synthesized as State.init(); no Content — no view() generated
    }

    @Feature
    private enum OverrideFeature {
        struct State: Sendable, Equatable { var count: Int }
        enum Action: Sendable { case noop }
        struct Environment: Sendable {}
        static func initialState(with _: Void) -> State { .init(count: 99) }
        static func behavior() -> Behavior<Action, State, Environment> { Reducer.reduce { _, _ in }.asBehavior() }
    }

    private struct StartCount: Sendable { var startingCount: Int }

    @Feature
    private enum SeededFeature {
        typealias Input = StartCount
        struct State: Sendable, Equatable { var count: Int }
        enum Action: Sendable { case noop }
        struct Environment: Sendable {}
        static func initialState(with input: Input) -> State { .init(count: input.startingCount) }
        static func behavior() -> Behavior<Action, State, Environment> { Reducer.reduce { _, _ in }.asBehavior() }
    }

    @Suite("@Feature — initialState synthesis")
    struct FeatureInitialStateTests {
        @Test func synthesizesVoidSeedFromEmptyInit() {
            #expect(CounterFeature.initialState(with: ()) == CounterFeature.State())
        }

        @Test func respectsUserOverride() {
            #expect(OverrideFeature.initialState(with: ()).count == 99)
        }

        @Test func usesCustomInputSeed() {
            #expect(SeededFeature.initialState(with: .init(startingCount: 42)).count == 42)
        }
    }
#endif
