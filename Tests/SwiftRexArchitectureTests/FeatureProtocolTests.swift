#if canImport(Observation) && canImport(SwiftUI)
import CoreFP
@testable import SwiftRex
@testable import SwiftRexArchitecture
import SwiftUI
import Testing

// Proves the Feature protocol lets you abstract over a feature generically — driving BOTH its
// behavior and its view without naming the concrete feature. Conformance is one line (`extension X:
// Feature {}`), which Swift's associated-type inference fills in from the @Feature-generated members.

@Feature(type: .internalOnly, strategy: .observationSimple)
enum FPLeaf {
    struct State: Sendable, Equatable { var n = 0 }
    enum Action: Sendable, Equatable { case bump }
    struct Environment: Sendable { var step: Int }
    static func behavior() -> Behavior<Action, State, Environment> {
        .reduce { action, state in
            switch action {
            case .bump: state.n += 1
            }
        }
    }
    typealias Content = FPLeafView
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@BoundTo(FPLeaf.self, strategy: .observationSimple)
struct FPLeafView: View { var body: some View { Text("\(viewStore.state.n)") } }

// One-line conformance — Body/Action/State/Environment inferred from the generated members.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension FPLeaf: Feature {}

// A generic that abstracts over ANY feature — driving both its behavior and its view through the
// single Feature protocol, without naming the concrete feature inside.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@MainActor
private func drive<F: Feature>(_ feature: F.Type, store: any StoreType<F.Action, F.State>, environment: F.Environment) -> F.Body {
    _ = F.behavior()
    return F.view(store: store, environment: environment)
}

@Suite("Feature protocol")
@MainActor
struct FeatureProtocolTests {
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func abstractsFeatureGenerically() {
        // Compiles ⇒ `drive` used a feature purely through the protocol (no concrete naming inside).
        let store = Store(initial: FPLeaf.State(), behavior: FPLeaf.behavior(), environment: FPLeaf.Environment(step: 1))
        _ = drive(FPLeaf.self, store: store, environment: FPLeaf.Environment(step: 1))
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func behaviorRunsThroughTheProtocol() {
        func featureBehavior<F: Feature>(_ f: F.Type) -> Behavior<F.Action, F.State, F.Environment> { F.behavior() }
        let store = Store(initial: FPLeaf.State(), behavior: featureBehavior(FPLeaf.self), environment: FPLeaf.Environment(step: 1))
        store.dispatch(.bump)
        #expect(store.state.n == 1)
    }
}
#endif
