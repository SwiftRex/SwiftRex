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
        case markAtPlayhead
    }

    // swiftlint:enable private_over_fileprivate

    @MainActor
    private func makeDocStore() -> Store<DocAction, DocState, Void> {
        Store(initial: DocState(), behavior: .identity, environment: ())
    }

    // MARK: - Owners

    private struct RootView: View {
        @OwnedStore var viewStore: ViewStore<DocAction, DocState>
        @OwnedStore var legacy: ViewStore<DocAction, DocState>

        init(appStore: Store<DocAction, DocState, Void>) {
            _viewStore = OwnedStore(wrappedValue: appStore.viewStore())
            _legacy = OwnedStore(wrappedValue: appStore.viewStore(.combine))
        }

        var body: some View {
            NavigationStack(path: viewStore.binding(.state(\.path).action(review: DocAction.setPath))) {
                PlayerScreen(viewStore: viewStore)
                    .navigationDestination(for: Route.self) { route in destination(route) }
            }
            .sheet(isPresented: viewStore.binding(.state(\.settings).action(\.closeSettings))) {
                if let settings = viewStore.traverse(.action(\.settings).state(\.settings)) {
                    SettingsView(store: settings)
                }
            }
        }

        @ViewBuilder func destination(_ route: Route) -> some View {
            switch route {
            case .detail:
                if let detail = viewStore.traverse(.action(\.detail).state(\.detail)) {
                    DetailView(store: detail)
                }
            }
        }
    }

    private struct DerivedOwner: View {
        @OwnedStore var viewStore: ViewStore<DocAction, String>

        init(appStore: some StoreType<DocAction, DocState>) {
            _viewStore = OwnedStore(wrappedValue: appStore
                .projection(action: { $0 }, state: \.transport)
                .buffer()
                .projection(action: { $0 }, state: { "\($0.position)" })
                .viewStore())
        }

        var body: some View { Text(viewStore.state.value) }
    }

    // An owner over an existential store — the usual type of an app's store property.
    private struct ExistentialOwner: View {
        @OwnedStore var viewStore: ViewStore<DocAction, DocState>

        init(appStore: any StoreType<DocAction, DocState>) {
            _viewStore = OwnedStore(wrappedValue: appStore.viewStore())
        }

        var body: some View { Text(viewStore.state.title) }
    }

    // MARK: - Receivers

    private struct PlayerScreen: View {
        let viewStore: ViewStore<DocAction, DocState>

        var body: some View {
            VStack {
                Text(viewStore.state.title)
                Console(mixer: viewStore.state.mixer)
                Playhead(transport: viewStore.state.transport)
                ForEach(viewStore.state.each(\.songs)) { SongRow(song: $0) }
                Button("Mark") { viewStore.dispatch(.markAtPlayhead) }
            }
        }
    }

    private struct Console: View {
        let mixer: GranularTracking<Mixer>
        var body: some View { Text("\(mixer.volume)") }
    }

    private struct Playhead: View {
        let transport: GranularTracking<Transport>
        var body: some View { Text("\(transport.position)") }
    }

    private struct SongRow: View {
        let song: GranularTracking<Song>
        var body: some View { Text(song.title) }
    }

    private struct SettingsView: View {
        @OwnedStore var viewStore: ViewStore<SettingsAction, Settings>
        init(store: some StoreType<SettingsAction, Settings>) { _viewStore = OwnedStore(wrappedValue: store.viewStore()) }
        var body: some View { Button("Dark: \(viewStore.state.darkMode)") { viewStore.dispatch(.toggleDark) } }
    }

    private struct DetailView: View {
        @OwnedStore var viewStore: ViewStore<DetailAction, Detail>
        init(store: some StoreType<DetailAction, Detail>) { _viewStore = OwnedStore(wrappedValue: store.viewStore()) }
        var body: some View { Text(viewStore.state.text) }
    }

    // MARK: - Tests

    @Suite("Observing a Store in SwiftUI — article snippets")
    @MainActor
    struct ObservingInSwiftUIDocTests {
        @Test func snippetsBuildTheirViews() {
            let appStore = makeDocStore()
            _ = RootView(appStore: appStore).body
            _ = DerivedOwner(appStore: appStore)
            _ = ExistentialOwner(appStore: appStore)
        }

        @Test func observeProjectObserveChainsThroughAViewStore() {
            let appStore = makeDocStore()
            let parent = appStore.viewStore()
            let child = parent.projection(action: { $0 }, state: { $0.title.uppercased() }).viewStore()
            #expect(child.state.value == "A")
        }
    }
#endif
