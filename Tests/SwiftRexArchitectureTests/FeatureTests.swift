#if canImport(Observation) && canImport(SwiftUI)
import DataStructure
import Observation
@testable import SwiftRex
@testable import SwiftRexArchitecture
import SwiftRexSwiftUI
import SwiftUI
import Testing

// MARK: - Feature fixture
//
// Mirrors the HeroDetailsFeature from Feature.swift docs, simplified so the test file
// is self-contained (ThreatLevel replaced by an Int index to avoid external dependencies).

private struct HeroDetailsView: View, HasViewModel {
    typealias VM = HeroDetailsFeature.ViewModel
    let viewModel: HeroDetailsFeature.ViewModel
    var body: Never { fatalError("test stub") }
}

@Feature(.internalScreen)
private enum HeroDetailsFeature {
    struct State: Sendable {
        var codename: String = "Kryptonian"
        var aliases: [String] = ["Superman", "Man of Steel"]
        var powers: [String] = ["flight", "heat vision"]
        var threatIndex: Int = 1       // 0 = low … 3 = critical
        var isRetired: Bool = false
    }

    enum Action: Sendable, Equatable {
        case savePowers([String])     // receives already-parsed array
        case setThreatIndex(Int)      // receives domain Int
        case toggleRetirement
    }

    struct Environment: Sendable {}

    @ViewModel
    // swiftlint:disable:next convenience_type
    final class ViewModel {
        struct ViewState: Sendable, Equatable {
            var displayName: String   // aliases.first ?? codename
            var powersText: String   // joined for TextField binding
            var threatIndex: Int      // segmented control index 0…3
            var isRetired: Bool
        }
        enum ViewAction: Sendable {
            case editedPowers(String) // raw comma-separated TextField content
            case selectedThreat(Int)  // segmented control index
            case tappedRetirement     // covers both retire and reinstate
        }
    }

    static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewModel.ViewState> { _ in
        { s in
            .init(
                displayName: s.aliases.first ?? s.codename,
                powersText: s.powers.joined(separator: ", "),
                threatIndex: s.threatIndex,
                isRetired: s.isRetired
            )
        }
    }

    static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { va in
        switch va {
        case .editedPowers(let raw):     // String  → [String]  (type change)
            .savePowers(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        case .selectedThreat(let index): // Int passthrough, name change
            .setThreatIndex(index)
        case .tappedRetirement:          // no value, name change
            .toggleRetirement
        }
    }

    static func initialState(with _: Void) -> State { .init() }

    static func behavior() -> Behavior<Action, State, Environment> {
        Reducer.reduce { (action: Action, state: inout State) in
            switch action {
            case .savePowers(let p):      state.powers = p
            case .setThreatIndex(let i):  state.threatIndex = i
            case .toggleRetirement:       state.isRetired.toggle()
            }
        }.asBehavior()
    }

    typealias Content = HeroDetailsView
}

// MARK: - Helpers

@MainActor
private func makeViewModel() -> HeroDetailsFeature.ViewModel {
    let store = Store(
        initial: HeroDetailsFeature.initialState(with: ()),
        behavior: HeroDetailsFeature.behavior(),
        environment: HeroDetailsFeature.Environment()
    )
    return HeroDetailsFeature.ViewModel(store: store.projection(
        action: HeroDetailsFeature.mapAction,
        state: HeroDetailsFeature.mapState(.init())
    ))
}

// MARK: - mapState tests

@Suite("HeroDetailsFeature.mapState")
@MainActor
struct MapStateTests {
    // `mapState` is curried over Environment; this feature's view ignores it (empty Environment).
    private func project(_ state: HeroDetailsFeature.State) -> HeroDetailsFeature.ViewModel.ViewState {
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

    @Test func passesThroughThreatIndexAndRetired() {
        let vs = project(.init(codename: "X", aliases: [], powers: [], threatIndex: 3, isRetired: true))
        #expect(vs.threatIndex == 3)
        #expect(vs.isRetired == true)
    }

    @Test func equatableDeduplication() {
        let a = project(.init())
        let b = project(.init())
        let c = project(.init(
            codename: "Kryptonian",
            aliases: ["Superman", "Man of Steel"],
            powers: ["flight"],
            threatIndex: 1,
            isRetired: false
        ))
        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - mapAction tests

@Suite("HeroDetailsFeature.mapAction")
struct MapActionTests {
    @Test func parsesCommaSeparatedPowers() {
        let action = HeroDetailsFeature.mapAction(.editedPowers("flight, strength, speed"))
        #expect(action == .savePowers(["flight", "strength", "speed"]))
    }

    @Test func stripsWhitespaceWhenParsingPowers() {
        let action = HeroDetailsFeature.mapAction(.editedPowers("  flight ,  heat vision  "))
        #expect(action == .savePowers(["flight", "heat vision"]))
    }

    @Test func mapsThreatIndexWithNameChange() {
        #expect(HeroDetailsFeature.mapAction(.selectedThreat(2)) == .setThreatIndex(2))
    }

    @Test func mapsRetirementTapWithNameChange() {
        #expect(HeroDetailsFeature.mapAction(.tappedRetirement) == .toggleRetirement)
    }
}

// MARK: - ViewModel field tests

@Suite("HeroDetailsFeature ViewModel")
@MainActor
struct ViewModelTests {
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func seedsFieldsFromInitialState() {
        let vm = makeViewModel()
        #expect(vm.displayName == "Superman")
        #expect(vm.powersText == "flight, heat vision")
        #expect(vm.threatIndex == 1)
        #expect(vm.isRetired == false)
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func savePowersUpdatesField() async {
        let vm = makeViewModel()
        vm.dispatch(.editedPowers("flying, invulnerability"))
        await Task.yield()
        #expect(vm.powersText == "flying, invulnerability")
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func toggleRetirementFlipsField() async {
        let vm = makeViewModel()
        vm.dispatch(.tappedRetirement)
        await Task.yield()
        #expect(vm.isRetired == true)
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func selectingThreatUpdatesIndex() async {
        let vm = makeViewModel()
        vm.dispatch(.selectedThreat(3))
        await Task.yield()
        #expect(vm.threatIndex == 3)
    }
}

// MARK: - generated view()

@Suite("@Feature — generated view()")
@MainActor
struct GeneratedViewTests {
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func viewBuildsFromStoreAndEnvironment() {
        // The macro-generated `view(store:environment:)` wires the ViewModel from an
        // environment-applied projection and returns the Content — constructs without touching body.
        let store = Store(
            initial: HeroDetailsFeature.initialState(with: ()),
            behavior: HeroDetailsFeature.behavior(),
            environment: HeroDetailsFeature.Environment()
        )
        _ = HeroDetailsFeature.view(store: store, environment: .init())
    }
}

// MARK: - @Feature macro — initialState synthesis
//
// Exercises the `@Feature` macro end-to-end (extension + memberAttribute + member roles).
// This fixture deliberately omits `initialState()` — `@Feature` synthesizes it as `State.init()`.

private struct CounterView: View, HasViewModel {
    typealias VM = CounterFeature.ViewModel
    let viewModel: CounterFeature.ViewModel
    var body: Never { fatalError("test stub") }
}

@Feature(.internalScreen)
private enum CounterFeature {
    struct State: Sendable {
        var count: Int = 7
        var label: String = "ready"
    }

    enum Action: Sendable, Equatable {
        case increment
    }

    struct Environment: Sendable {}

    // swiftlint:disable:next convenience_type
    final class ViewModel {
        struct ViewState: Sendable, Equatable {
            var count: Int
        }
        enum ViewAction: Sendable {
            case tapped
        }
    }

    static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewModel.ViewState> { _ in
        { .init(count: $0.count) }
    }
    static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { _ in .increment }

    // No `initialState()` here — synthesized by `@Feature`.

    static func behavior() -> Behavior<Action, State, Environment> {
        Reducer.reduce { (action: Action, state: inout State) in
            switch action {
            case .increment: state.count += 1
            }
        }.asBehavior()
    }

    typealias Content = CounterView
}

// A feature that supplies its own `initialState()` — `@Feature` must NOT also synthesize one
// (a second declaration would be an "invalid redeclaration" compile error).

private struct OverrideView: View, HasViewModel {
    typealias VM = OverrideFeature.ViewModel
    let viewModel: OverrideFeature.ViewModel
    var body: Never { fatalError("test stub") }
}

@Feature(.internalScreen)
private enum OverrideFeature {
    struct State: Sendable {
        var count: Int = 0
    }

    enum Action: Sendable, Equatable {
        case noop
    }

    struct Environment: Sendable {}

    // swiftlint:disable:next convenience_type
    final class ViewModel {
        struct ViewState: Sendable, Equatable {
            var count: Int
        }
        enum ViewAction: Sendable {
            case tapped
        }
    }

    static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewModel.ViewState> { _ in
        { .init(count: $0.count) }
    }
    static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { _ in .noop }

    static func initialState(with _: Void) -> State { .init(count: 99) }

    static func behavior() -> Behavior<Action, State, Environment> {
        Reducer.reduce { (_: Action, _: inout State) in }.asBehavior()
    }

    typealias Content = OverrideView
}

// A feature with a non-`Void` `Input` seed — `@Feature` must NOT synthesize `initialState`
// (it can't know how to build `State` from a custom seed), so the feature writes its own
// `initialState(with:)` that threads the seed into the initial state.

private struct SeededView: View, HasViewModel {
    typealias VM = SeededFeature.ViewModel
    let viewModel: SeededFeature.ViewModel
    var body: Never { fatalError("test stub") }
}

@Feature(.internalScreen)
private enum SeededFeature {
    struct Input: Sendable {
        var startingCount: Int
    }

    struct State: Sendable {
        var count: Int = 0
    }

    enum Action: Sendable, Equatable {
        case noop
    }

    struct Environment: Sendable {}

    // swiftlint:disable:next convenience_type
    final class ViewModel {
        struct ViewState: Sendable, Equatable {
            var count: Int
        }
        enum ViewAction: Sendable {
            case tapped
        }
    }

    static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewModel.ViewState> { _ in
        { .init(count: $0.count) }
    }
    static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { _ in .noop }

    static func initialState(with input: Input) -> State { .init(count: input.startingCount) }

    static func behavior() -> Behavior<Action, State, Environment> {
        Reducer.reduce { (_: Action, _: inout State) in }.asBehavior()
    }

    typealias Content = SeededView
}

@Suite("@Feature — initialState synthesis")
struct FeatureInitialStateTests {
    @Test func synthesizesInitialStateFromStateDefaults() {
        let state = CounterFeature.initialState(with: ())
        #expect(state.count == 7)
        #expect(state.label == "ready")
    }

    @Test func attachesPrismsNamespaceToAction() {
        // Confirms `@Feature` attaches `@Prisms`: the prism namespace exists…
        #expect(CounterFeature.Action.prism.increment.preview(.increment) != nil)
        // …and the cases mirror is emitted.
        #expect(CounterFeature.Action.increment.is(.increment))
    }

    @Test func userSuppliedInitialStateWins() {
        // Compiles only because `@Feature` skipped synthesis (no redeclaration), and returns
        // the user's value rather than `State.init()` defaults.
        #expect(OverrideFeature.initialState(with: ()).count == 99)
    }

    @Test func customInputSeedsInitialState() {
        // A non-`Void` `Input` threads a construction-time seed into the initial state.
        #expect(SeededFeature.initialState(with: .init(startingCount: 42)).count == 42)
    }
}

// MARK: - mapState environment injection
//
// A feature whose view formats via an injected dependency — proves `mapState` is curried over
// `Environment` and the value reaches the projection at view-build time, without pushing
// formatting into `Behavior`/`State`.

private struct FormattingView: View, HasViewModel {
    typealias VM = FormattingFeature.ViewModel
    let viewModel: FormattingFeature.ViewModel
    var body: Never { fatalError("test stub") }
}

@Feature(.internalScreen)
private enum FormattingFeature {
    struct State: Sendable, Equatable {
        var amount: Int = 5
    }

    enum Action: Sendable, Equatable {
        case noop
    }

    struct Environment: Sendable {
        var formatMoney: @Sendable (Int) -> String
    }

    // swiftlint:disable:next convenience_type
    final class ViewModel {
        struct ViewState: Sendable, Equatable {
            var display: String
        }
        enum ViewAction: Sendable {
            case tapped
        }
    }

    static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewModel.ViewState> { env in
        { state in .init(display: env.formatMoney(state.amount)) }
    }
    static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { _ in .noop }

    static func behavior() -> Behavior<Action, State, Environment> {
        Reducer.reduce { (_: Action, _: inout State) in }.asBehavior()
    }

    typealias Content = FormattingView
}

@Suite("mapState — environment injection")
@MainActor
struct MapStateEnvironmentTests {
    @Test func mapStateUsesInjectedEnvironment() {
        let env = FormattingFeature.Environment(formatMoney: { "$\($0).00" })
        #expect(FormattingFeature.mapState(env)(.init(amount: 7)).display == "$7.00")
    }

    @Test func differentEnvironmentsFormatDifferently() {
        let dollars = FormattingFeature.Environment(formatMoney: { "$\($0)" })
        let euros = FormattingFeature.Environment(formatMoney: { "€\($0)" })
        #expect(FormattingFeature.mapState(dollars)(.init(amount: 3)).display == "$3")
        #expect(FormattingFeature.mapState(euros)(.init(amount: 3)).display == "€3")
    }
}
#endif
