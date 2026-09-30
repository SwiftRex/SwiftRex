// SPDX-License-Identifier: Apache-2.0

// The recommended app shape: a container `@Feature` whose hand-written `view` owns the observed store
// (`ObservableStoreHost`) and hands a `ViewStore` to a router and a root view.

#if canImport(AppKit) && canImport(SwiftUI) && canImport(Combine)
    import AppKit
    import SwiftRex
    import SwiftRexArchitecture
    import SwiftUI
    import Testing

    @Feature
    enum RPChild {
        struct State: Sendable, Equatable { var count = 0 }
        enum Action: Sendable, Equatable { case inc }
        struct Environment: Sendable { var step: Int }

        static func behavior() -> Behavior<Action, State, Environment> {
            .handle { action, _ in
                switch action {
                case .inc: .reduce { $0.count += 1 }
                }
            }
        }

        typealias Content = RPChildView
    }

    @BoundTo(RPChild.self)
    struct RPChildView: View {
        var body: some View { Text("\(viewStore.state.count)") }
    }

    struct RPWorld: Sendable {
        var step = 1
    }

    enum RPRoute: Sendable, Hashable {
        case child
    }

    @Feature
    enum RPApp {
        struct State: Sendable, Equatable {
            var child = RPChild.State()
            var path: [RPRoute] = []
        }

        enum Action: Sendable, Equatable {
            case child(RPChild.Action)
            case setPath([RPRoute])
        }

        typealias Environment = RPWorld

        @MainActor
        static func view(store: any StoreType<Action, State>, environment: RPWorld) -> some View {
            ProjectionKeeper { store } content: { viewStore in
                RPRootView(viewStore: viewStore, router: RPRouter(store: viewStore, world: environment))
            }
        }

        static func behavior() -> Behavior<Action, State, RPWorld> {
            Behavior.combine([
                RPScopes.child.behavior(of: RPChild.self),
                .reduce { action, state in
                    if case let .setPath(path) = action { state.path = path }
                }
            ])
        }
    }

    enum RPScopes: Rig {
        typealias Action = RPApp.Action
        typealias State = RPApp.State
        typealias Environment = RPWorld

        static let child = ScopeOf<RPScopes>
            .action(\.child)
            .state(\.child)
            .environment { world in RPChild.Environment(step: world.step) }
    }

    @MainActor
    struct RPRouter {
        let store: ViewStore<RPApp.Action, RPApp.State>
        let world: RPWorld

        func root() -> some View {
            RPScopes.child.view(of: RPChild.self, from: store, world: world)
        }

        @ViewBuilder
        func destination(for route: RPRoute) -> some View {
            switch route {
            case .child: RPScopes.child.view(of: RPChild.self, from: store, world: world)
            }
        }
    }

    struct RPRootView: View, Routable {
        let viewStore: ViewStore<RPApp.Action, RPApp.State>
        let router: RPRouter

        var body: some View {
            NavigationStack(path: viewStore.binding(.state(\.path).action(\.setPath))) {
                router.root().navigationDestination(for: RPRoute.self) { router.destination(for: $0) }
            }
        }
    }

    @Suite("App feature + router pattern")
    @MainActor
    struct AppFeatureRouterPatternTests {
        @Test func containerFeatureOwnsTheStoreAndTheRouterReceivesIt() {
            let store = Store(initial: RPApp.initialState(with: ()), behavior: RPApp.behavior(), environment: RPWorld())
            let host = NSHostingView(rootView: RPApp.view(store: store, environment: RPWorld()))
            host.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            host.layoutSubtreeIfNeeded()
            store.dispatch(.child(.inc))
            store.dispatch(.setPath([.child]))
            host.needsLayout = true
            host.layoutSubtreeIfNeeded()
            #expect(store.currentState.child.count == 1)
            #expect(store.currentState.path == [.child])
        }
    }
#endif
