#if canImport(Observation)
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

private enum HeroDetailsFeature: Feature {
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

    static let mapState: @MainActor @Sendable (State) -> ViewModel.ViewState = { s in
        .init(
            displayName: s.aliases.first ?? s.codename,
            powersText: s.powers.joined(separator: ", "),
            threatIndex: s.threatIndex,
            isRetired: s.isRetired
        )
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

    static func initialState() -> State { .init() }

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
        initial: HeroDetailsFeature.initialState(),
        behavior: HeroDetailsFeature.behavior(),
        environment: HeroDetailsFeature.Environment()
    )
    return HeroDetailsFeature.ViewModel(store: store.projection(
        action: HeroDetailsFeature.mapAction,
        state: HeroDetailsFeature.mapState
    ))
}

// MARK: - mapState tests

@Suite("HeroDetailsFeature.mapState")
@MainActor
struct MapStateTests {
    @Test func usesFirstAliasAsDisplayName() {
        let vs = HeroDetailsFeature.mapState(.init())
        #expect(vs.displayName == "Superman")
    }

    @Test func fallsBackToCodenameWhenNoAliases() {
        let vs = HeroDetailsFeature.mapState(
            .init(codename: "Unknown", aliases: [], powers: [], threatIndex: 0, isRetired: false)
        )
        #expect(vs.displayName == "Unknown")
    }

    @Test func joinsPowersWithComma() {
        let vs = HeroDetailsFeature.mapState(.init())
        #expect(vs.powersText == "flight, heat vision")
    }

    @Test func passesThroughThreatIndexAndRetired() {
        let state = HeroDetailsFeature.State(
            codename: "X", aliases: [], powers: [], threatIndex: 3, isRetired: true
        )
        let vs = HeroDetailsFeature.mapState(state)
        #expect(vs.threatIndex == 3)
        #expect(vs.isRetired == true)
    }

    @Test func equatableDeduplication() {
        let a = HeroDetailsFeature.mapState(.init())
        let b = HeroDetailsFeature.mapState(.init())
        let c = HeroDetailsFeature.mapState(.init(
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
#endif
