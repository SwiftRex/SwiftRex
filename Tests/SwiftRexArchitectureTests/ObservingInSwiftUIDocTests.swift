// SPDX-License-Identifier: Apache-2.0

// Compile-and-run checks for the snippets in `ObservingInSwiftUI.md` — the manual (non-@Feature) path.

#if canImport(SwiftUI) && canImport(Combine)
    import SwiftRex
    import SwiftRexArchitecture
    import SwiftUI
    import Testing

    // swiftlint:disable private_over_fileprivate

    // MARK: - Domain

    fileprivate struct Song: Sendable, Equatable, Identifiable {
        var id: Int
        var title: String
    }

    fileprivate struct Transport: Sendable, Equatable {
        var position: Double = 0
    }

    fileprivate struct Mixer: Sendable, Equatable {
        var volume: Double = 1
    }

    fileprivate struct Settings: Sendable, Equatable {
        var darkMode = false
    }

    fileprivate struct Detail: Sendable, Equatable {
        var text = ""
    }

    fileprivate enum Route: Sendable, Hashable {
        case detail
    }

    fileprivate struct DocState: Sendable, Equatable {
        var title = "a"
        var path: [Route] = []
        var songs: [Song] = [Song(id: 1, title: "one")]
        var transport = Transport()
        var mixer = Mixer()
        var settings: Settings?
        var detail: Detail?
    }

    @Prisms
    fileprivate enum SettingsAction: Sendable {
        case toggleDark
    }

    @Prisms
    fileprivate enum DetailAction: Sendable {
        case edit(String)
    }

    @Prisms
    fileprivate enum DocAction: Sendable {
        case setPath([Route])
        case closeSettings
        case settings(SettingsAction)
        case detail(DetailAction)
        case mark(Double)
    }

    // swiftlint:enable private_over_fileprivate

    @MainActor
    private func makeDocStore() -> Store<DocAction, DocState, Void> {
        Store(initial: DocState(), behavior: .identity, environment: ())
    }

    // MARK: - Owners

    private struct RootView: View {
        @ObservedStore var store: ViewStore<DocAction, DocState>
        @ObservedStore var legacy: ViewStore<DocAction, DocState>

        init(appStore: Store<DocAction, DocState, Void>) {
            _store = ObservedStore(wrappedValue: appStore)
            _legacy = ObservedStore(wrappedValue: appStore, .combine)
        }

        var body: some View {
            NavigationStack(path: store.binding(.state(\.path), dispatch: .action(review: DocAction.setPath))) {
                PlayerScreen(store: store)
                    .navigationDestination(for: Route.self) { route in destination(route) }
            }
            .sheet(isPresented: store.presence(.state(\.settings), dismiss: .closeSettings)) {
                if let settings = store.settings.unwrapped() {
                    SettingsView(store: settings.scoped(action: .action(\.settings)))
                }
            }
        }

        @ViewBuilder func destination(_ route: Route) -> some View {
            switch route {
            case .detail:
                if let detail = store.detail.scoped(action: .action(\.detail)).transpose() {
                    ObservableStoreHost { detail.observable() } content: { DetailView(store: $0) }
                }
            }
        }
    }

    private struct DerivedOwner: View {
        @ObservedStore var screen: ViewStore<DocAction, String>

        init(appStore: some StoreType<DocAction, DocState>) {
            _screen = ObservedStore(wrappedValue: appStore
                .projection(action: { $0 }, state: \.transport)
                .buffer()
                .projection(action: { $0 }, state: { "\($0.position)" }))
        }

        var body: some View { Text(screen.state) }
    }

    // MARK: - Receivers

    private struct PlayerScreen: View {
        let store: ViewStore<DocAction, DocState>

        var body: some View {
            VStack {
                Text(store.title)
                Console(mixer: store.mixer)
                Playhead(transport: store.transport)
                ForEach(store.each(\.songs)) { SongRow(song: $0) }
                Button("Mark") { store.dispatch(.mark(store.peek(\.transport.position))) }
            }
        }
    }

    private struct Console: View {
        let mixer: StateNode<ViewStore<DocAction, DocState>, Mixer>
        var body: some View { Text("\(mixer.volume)") }
    }

    private struct Playhead: View {
        let transport: StateNode<ViewStore<DocAction, DocState>, Transport>
        var body: some View { Text("\(transport.position)") }
    }

    private struct SongRow: View {
        let song: StateNode<ViewStore<DocAction, DocState>, Song>
        var body: some View { Text(song.title) }
    }

    private struct SettingsView: View {
        let store: ScopedStore<DocAction, DocState, SettingsAction, Settings>
        var body: some View { Button("Dark: \(store.darkMode)") { store.dispatch(.toggleDark) } }
    }

    private struct DetailView: View {
        let store: ViewStore<DetailAction, Detail>
        var body: some View { Text(store.text) }
    }

    // MARK: - Tests

    @Suite("Observing a Store in SwiftUI — article snippets")
    @MainActor
    struct ObservingInSwiftUIDocTests {
        @Test func snippetsBuildTheirViews() {
            let appStore = makeDocStore()
            _ = RootView(appStore: appStore).body
            _ = DerivedOwner(appStore: appStore)
        }

        @Test func observeProjectObserveChainsThroughAViewStore() {
            let appStore = makeDocStore()
            let parent = ViewStore(appStore.observable())
            let child = parent.projection(action: { $0 }, state: { $0.title.uppercased() }).observable()
            #expect(child.state == "A")
        }
    }
#endif
