// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    import CoreFP
    import FPMacros
    @testable import SwiftRex
    @testable import SwiftRexArchitecture
    import Testing

    // Proves `@Feature` applies recursive optics — via `@ApplyOptics(recursively: true)` — to nested
    // domain state at any depth (not just top-level `State`/`Action`), and that the cross-macro
    // interaction (`@Feature`'s memberAttribute ADDING `@ApplyOptics`) still drives the recursion cycle.
    @Feature(type: .internalOnly, strategy: .observationSimple)
    enum OpticsProbeFeature {
        struct State: Sendable, Equatable {
            var count: Int = 0
            var sub: Sub = .init()
            var route: Route = .home

            struct Sub: Sendable, Equatable {
                var name: String = ""
                struct Deep: Sendable, Equatable { var flag: Bool = false } // depth 2
                var deep: Deep = .init()
            }

            enum Route: Sendable, Equatable {
                case home
                case detail(Int)
            }
        }

        enum Action: Sendable {
            case tap
            case sub(SubAction) // an inner enum, gets prisms too
        }

        enum SubAction: Sendable { case ping(String) }

        static func behavior() -> Behavior<Action, State, Void> { .reduce { _, _ in } }
    }

    @Suite("@Feature — recursive optics")
    struct FeatureRecursiveOpticsTests {
        @Test func topLevelStateAndAction() {
            #expect(OpticsProbeFeature.State.lens.count.get(.init()) == 0)
            #expect(OpticsProbeFeature.Action.prism.tap.preview(.tap) != nil)
        }

        @Test func nestedStateStructGetsLenses() {
            #expect(OpticsProbeFeature.State.Sub.lens.name.set(.init(), "x").name == "x")
            // depth 2
            #expect(OpticsProbeFeature.State.Sub.Deep.lens.flag.set(.init(), true).flag == true)
        }

        @Test func nestedStateEnumGetsPrisms() {
            #expect(OpticsProbeFeature.State.Route.prism.detail.preview(.detail(3)) == 3)
            #expect((OpticsProbeFeature.State.Route.self as Any.Type) is any Prismatic.Type)
        }

        @Test func nestedActionEnumGetsPrisms() {
            #expect(OpticsProbeFeature.SubAction.prism.ping.preview(.ping("hi")) == "hi")
        }
    }
#endif
