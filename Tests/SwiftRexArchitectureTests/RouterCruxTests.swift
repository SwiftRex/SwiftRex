// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    import CoreFP
    @testable import SwiftRex
    @testable import SwiftRexArchitecture
    import SwiftUI
    import Testing

    // Proves the navigation crux is resolved: a parent view whose body is ENVIRONMENT-FREE presents a
    // child built WITH its environment — supplied by the router, never by the view body. Also proves
    // cross-feature decoupling (the parent never names the child) and no AnyView (@ViewBuilder switch).

    // A leaf "module" with a NON-Void environment — so building its view demonstrably needs env.
    @Feature(strategy: .observationSimple)
    enum RDetail {
        struct State: Sendable, Equatable { var text = "detail" }
        enum Action: Sendable, Equatable { case tap }
        struct Environment: Sendable { var greet: @Sendable () -> String }
        static func behavior() -> Behavior<Action, State, Environment> {
            .reduce { action, state in
                switch action {
                case .tap: state.text = "tapped"
                }
            }
        }

        typealias Content = RDetailView
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @BoundTo(RDetail.self, strategy: .observationSimple)
    struct RDetailView: View {
        var body: some View { Text(viewStore.state.text) }
    }

    // @Prisms requires >= fileprivate.
    // swiftlint:disable private_over_fileprivate
    @Prisms
    fileprivate enum RAppAction: Sendable {
        case detail(RDetail.Action)
        case dismiss
    }

    @Lenses
    fileprivate struct RAppState: Sendable {
        var detail = RDetail.State() // sibling slice; the route is just a trigger token
        var route: RAppRoute?
    }

    fileprivate enum RAppRoute: Hashable, Sendable { case detail }

    fileprivate struct RWorld: Sendable { var greet: @Sendable () -> String = { "hi" } }

    // The router: one concrete type that knows the whole tree. Its @ViewBuilder switch resolves a route
    // to a child view, supplying that child's env — the crux — and keeping `some View` (no AnyView).
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @MainActor
    fileprivate struct RAppRouter {
        let store: Store<RAppAction, RAppState, RWorld>
        let world: RWorld

        @ViewBuilder
        func view(for route: RAppRoute) -> some View {
            switch route {
            case .detail:
                RDetail.view(
                    store: store.projection(action: \.detail, state: \.detail), // prism + key-path sugar
                    environment: RDetail.Environment(greet: world.greet) // env supplied HERE
                )
            }
        }
    }

    // The parent view: it holds only a `viewStore` and a `router` — NO environment. It presents the
    // detail through the router and never names `RDetail`. Cross-feature decoupling + crux resolution.
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    fileprivate struct RHomeView: View, Routable {
        let viewStore: ViewStore<RAppState, RAppAction>
        let router: RAppRouter

        var body: some View {
            Text("home")
                .sheet(isPresented: viewStore.presence(\.route, dismiss: .dismiss)) {
                    router.view(for: .detail) // env-free body; the router supplied env — crux resolved
                }
        }
    }

    // swiftlint:enable private_over_fileprivate

    @Suite("Router — crux resolution")
    @MainActor
    struct RouterCruxTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        private func makeStore() -> Store<RAppAction, RAppState, RWorld> {
            Store(
                initial: RAppState(),
                behavior: RDetail.behavior().lift(
                    Relay.Empty.action(RAppAction.prism.detail)
                        .state(\RAppState.detail)
                        .environment { (world: RWorld) in RDetail.Environment(greet: world.greet) }
                ),
                environment: RWorld()
            )
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func envFreeParentPresentsChildBuiltWithEnv() {
            // Compiles ⇒ the router resolves a route to a child view WITH env, from an env-free parent.
            let store = makeStore()
            let router = RAppRouter(store: store, world: RWorld())
            let home = RHomeView(viewStore: ViewStore(store), router: router)
            _ = home.router.view(for: .detail)
            _ = home.body
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func routedChildSharesTheOneStore() {
            // The child dispatches into the same single store; its behavior (lifted) runs.
            let store = makeStore()
            store.dispatch(.detail(.tap))
            #expect(store.state.detail.text == "tapped")
        }
    }
#endif
