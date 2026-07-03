#if canImport(Observation) && canImport(SwiftUI)
import DataStructure
@testable import SwiftRex
@testable import SwiftRexArchitecture
import SwiftRexSwiftConcurrency
import SwiftUI
import Testing

// Compile-checks for the code examples in Features.md and the README `# SwiftRex Architecture`
// section — the parts not already covered by the fixtures (L4: effect, navigation, composing;
// and an L2 two-way binding). If the docs drift from the real API, this stops compiling.

struct Book: Identifiable, Sendable, Equatable { let id: String; var title: String }

// MARK: - L4 — a full module (Input seed, effect, state-driven navigation)

@Feature(type: .moduleEntryPoint, strategy: .observationSimple)
enum Library {
    struct Input: Sendable { var shelfID: String }

    struct State: Sendable, Equatable {
        var shelfID: String
        var isLoading = false
        var books: [Book] = []
        // Explicit `= nil`: @Lenses (applied by @Feature) generates the memberwise init and only
        // defaults params whose property has an explicit default.
        // swiftlint:disable:next implicit_optional_initialization
        var selected: Book? = nil
    }

    enum Action: Sendable {
        case onAppear
        case loaded([Book])
        case tapped(Book)
        case dismissedDetail
    }

    struct Environment: Sendable {
        var fetch: @Sendable (String) async -> [Book]
    }

    static func initialState(with input: Input) -> State { .init(shelfID: input.shelfID) }

    static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, _ in
            switch action {
            case .onAppear:
                .reduce { $0.isLoading = true }
                .produce { ctx in
                    Effect.task {
                        let shelf = await ctx.liveState?.shelfID ?? ""
                        return .loaded(await ctx.environment.fetch(shelf))
                    }
                }
            case .loaded(let books):
                .reduce { $0.books = books; $0.isLoading = false }
            case .tapped(let book):
                .reduce { $0.selected = book }
            case .dismissedDetail:
                .reduce { $0.selected = nil }
            }
        }
    }

    typealias Content = LibraryView
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@BoundTo(Library.self, strategy: .observationSimple)
struct LibraryView: View {
    var body: some View {
        List(viewStore.state.books) { book in
            Button(book.title) { viewStore.dispatch(.tapped(book)) }
        }
        .onAppear { viewStore.dispatch(.onAppear) }
        .sheet(item: viewStore.item(\.selected, dismiss: .dismissedDetail)) { book in
            Text(book.title)
        }
    }
}

// MARK: - L2 — a distinct view shape with a two-way binding

@Feature(type: .internalOnly, strategy: .observationSimple)
enum Editor {
    struct State: Sendable, Equatable { var powers = ["flight"] }
    enum Action: Sendable, Equatable { case savePowers([String]) }
    struct ViewState: Sendable, Equatable { var powersText: String }
    enum ViewAction: Sendable { case editedPowers(String) }

    static let mapState = Reader<Void, @MainActor @Sendable (State) -> ViewState> { _ in
        { .init(powersText: $0.powers.joined(separator: ", ")) }
    }
    static let mapAction = Reader<Void, @Sendable (ViewAction) -> Action> { _ in
        { va in
            switch va {
            case .editedPowers(let raw): .savePowers(raw.split(separator: ",").map(String.init))
            }
        }
    }
    static func behavior() -> Behavior<Action, State, Environment> {
        .reduce { action, state in
            switch action {
            case .savePowers(let p): state.powers = p
            }
        }
    }
    typealias Content = EditorView
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@BoundTo(Editor.self, strategy: .observationSimple)
struct EditorView: View {
    var body: some View {
        TextField("Powers", text: viewStore.binding(\.powersText, set: { .editedPowers($0) }))
    }
}

// MARK: - Composing modules into an app store (lift + liftOptional)

@Prisms
enum AppAction: Sendable {
    case library(Library.Action)
    case editor(Editor.Action)
}

@Lenses
struct AppState: Sendable {
    var library = Library.State(shelfID: "sci-fi")
    // swiftlint:disable:next implicit_optional_initialization
    var editor: Editor.State? = nil
}

struct AppEnv: Sendable {
    var library: Library.Environment
    var editor: Editor.Environment
}

@Suite("Doc examples compile")
@MainActor
struct DocExamplesTests {
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func moduleRendersAndComposes() {
        let appBehavior = Behavior.combine(
            Library.behavior().lift(
                action: AppAction.prism.library,
                state: \AppState.library,
                environment: { (e: AppEnv) in e.library }
            ),
            Editor.behavior().liftOptional(
                action: AppAction.prism.editor,
                state: \AppState.editor,
                environment: { (e: AppEnv) in e.editor }
            )
        )
        let store = Store(
            initial: AppState(),
            behavior: appBehavior,
            environment: AppEnv(library: .init(fetch: { _ in [] }), editor: ())
        )
        _ = Library.view(
            store: store.projection(action: AppAction.library, state: { $0.library }),
            environment: Library.Environment(fetch: { _ in [] })
        )
    }
}
#endif
