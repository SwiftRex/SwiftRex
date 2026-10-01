# Navigation, End to End

Build one small app — **Bookshelf** — and wire every navigation shape across every layer: domain, features, the global feature, the behavior fold, scopes, the router, the views, and the `@main` assembly.

## Overview

<doc:Navigation> is the reference — the four state shapes and every container, by shape. This article is the *follow-along*: one app that uses all of them together, shown top to bottom so you can copy the whole stack, not a snippet.

**Bookshelf** has:

```
TabView  (selection)  ─┬─  Library tab
                       │      └─ NavigationStack (stack):  Shelves ─▶ Books ─▶ Book
                       │            └─ Book: "Edit" ─▶ Editor      (presentation modal)
                       │                    "Delete" ─▶ confirm    (optional)
                       └─  Settings tab
deep link:  bookshelf://book/<id>  ─▶  select Library, push to that book
```

That's all four shapes: **selection** (tabs), **stack** (the push path), **presentation** (the animated editor modal), and **optional** (the delete alert) — plus a deep link in. We build it one layer at a time.

## Layer 1 — Domain (`AppDomain`)

Pure data, no side effects. `AppRoute` is the stack's element — a DTO whose payloads are domain types, so a feature can navigate without importing the router.

```swift
// AppDomain — depended on by every module; no SwiftUI, no store.
public struct Book: Sendable, Equatable, Identifiable { public var id: Int; public var title: String; public var notes: String }
public struct Shelf: Sendable, Equatable, Identifiable { public var id: Int; public var name: String; public var bookIDs: [Int] }

public enum Tab: Sendable, Hashable { case library, settings }

// The stack route — one case per pushable screen. Payloads are domain types (or ids).
public enum AppRoute: Sendable, Hashable {
    case shelf(Shelf.ID)
    case book(Book.ID)
}
```

## Layer 2 — The leaf features (`@Feature`)

Each screen is a feature `enum`. Access follows the declaration: a `public enum` is a module entry point (public members), a plain `enum` is internal to a module. `@Feature` generates optics, `initialState(with:)`, the `view()`, and the `Feature` conformance.

```swift
// LibraryFeature — the shelves list (a module entry point).
@Feature
public enum LibraryFeature {
    public struct State: Sendable, Equatable { public var shelves: [Shelf] = [] }
    public enum Action: Sendable { case onAppear; case loaded([Shelf]); case tappedShelf(Shelf.ID) }
    public struct Environment: Sendable { public var loadShelves: @Sendable () -> Publisher<[Shelf], Never> }

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, _ in
            switch action {
            case .onAppear: .produce { ctx in ctx.environment.loadShelves().asEffect(Action.loaded) }
            case let .loaded(s): .reduce { $0.shelves = s }
            case .tappedShelf: .doNothing // OUTPUT — the app bridges this into a push (Layer 4)
            }
        }
    }
    typealias Content = LibraryView // the view layer stays internal
}

// BookFeature — a single book; owns "edit" + "delete" intents (a module entry point).
@Feature
public enum BookFeature {
    public struct State: Sendable, Equatable { public var book: Book; public var deleting: Book? }
    public enum Action: Sendable { case tappedEdit; case tappedDelete; case confirmDelete; case cancelDelete }
    public struct Environment: Sendable {}

    public static func behavior() -> Behavior<Action, State, Environment> {
        .reduce { action, state in
            switch action {
            case .tappedDelete: state.deleting = state.book // the alert's content IS the presentation
            case .cancelDelete: state.deleting = nil
            case .tappedEdit, .confirmDelete: break // OUTPUT — bridged by the app (Layer 4)
            }
        }
    }
    typealias Content = BookView
}

// EditorFeature — the modal editor (a module entry point).
@Feature
public enum EditorFeature {
    public struct State: Sendable, Equatable, Identifiable { public var book: Book; public var id: Book.ID { book.id } }
    public enum Action: Sendable { case editedTitle(String); case editedNotes(String); case tappedSave; case tappedCancel }
    public struct Environment: Sendable { public var save: @Sendable (Book) -> Publisher<Void, Never> }

    public static func initialState(with book: Book) -> State { .init(book: book) }
    public typealias Input = Book

    public static func behavior() -> Behavior<Action, State, Environment> {
        .reduce { action, state in
            switch action {
            case let .editedTitle(t): state.book.title = t
            case let .editedNotes(n): state.book.notes = n
            case .tappedSave, .tappedCancel: break // OUTPUT — bridged to dismiss (Layer 4)
            }
        }
    }
    typealias Content = EditorView
}
```

> `EditorFeature.State` is `Identifiable` (by the book's id) — that stable id is what lets it drive a `.sheet(item:)` without churning identity (Layer 6).

## Layer 3 — The global feature: where every shape is *stored*

The whole app is one `FeatureDomain` (the `SwiftRex.Architecture` name for a ``Rig``) — the parent that scopes hang off. Its `State`/`Action`/`Environment` is where each navigation shape lives. **This is the "how do I store this" answer:**

```swift
// AppFeature — the parent FeatureDomain. `Relay.Scope` (declared in `AppScopes`) embeds each child here.
public enum AppFeature: FeatureDomain {
    public typealias Action = AppAction
    public typealias State = AppState
    public typealias Environment = World
}

@Lenses
public struct AppState: Sendable, Equatable {
    // selection shape → a plain value
    public var tab: Tab = .library
    // stack shape → an ordered array of routes
    public var path: [AppRoute] = []
    // presentation shape → the three-stage lifecycle
    public var editor: Presentation<EditorFeature.State> = .dismissed
    // the feature state slices (present siblings, always alive)
    public var library = LibraryFeature.State()
    public var book: BookFeature.State? // optional: only while a book is on the stack
}

@Prisms
public enum AppAction: Sendable {
    // one nav-operation case per shape (payload enums from SwiftRex.Architecture)
    case tab(SelectionNavigation<Tab>) // .select(tab)
    case nav(StackNavigation<AppRoute>) // .push / .pop / .popToRoot / .setPath
    case editor(PresentationAction<EditorFeature.Action>) // .dismiss / .dismissed / .child — no State in the action
    // the child features' own actions
    case library(LibraryFeature.Action)
    case book(BookFeature.Action)
    case openedURL(URL) // deep link in
}
```

| Shape | Stored in `AppState` as | Driven by `AppAction` case |
|---|---|---|
| Selection (tabs) | `tab: Tab` | `.tab(SelectionNavigation<Tab>)` |
| Stack (push path) | `path: [AppRoute]` | `.nav(StackNavigation<AppRoute>)` |
| Presentation (editor modal) | `editor: Presentation<EditorFeature.State>` | `.editor(PresentationAction<…>)` |
| Optional (delete alert) | `book.deleting: Book?` (inside the book slice — the book being confirmed) | `.book(.tappedDelete/.cancelDelete)` |

## Layer 4 — `behavior()`: fold the features + drive the shapes

The app behavior is a monoid fold of: each child's **lifted** behavior, one reducer **per navigation shape**, and **bridges** that turn child outputs into navigation.

```swift
public extension AppFeature {
    static func behavior(world: World) -> Behavior<AppAction, AppState, World> {
        Behavior.combine([
            // 1. children, lifted to the app types
            // a present sibling → a declared scope, total lift
            AppScopes.library.behavior(of: LibraryFeature.self),
            // an optional \.book → affine state lane: runs only while a book is on the stack
            BookFeature.behavior().lift(.action(\.book).state(\.book).environment { _ in BookFeature.Environment() }),
            // a presentation slot → the stage machine + the child, in one lift
            EditorFeature.behavior().liftPresentation(
                action: \.editor,
                state: \.editor,
                environment: { $0.editorEnv }
            ),

            // 2. one reducer per navigation shape (from SwiftRex.Architecture)
            .navigationSelection(\.tab, action: \.tab), // selection
            .navigationStack(\.path, action: \.nav), // stack: push/pop/setPath

            // 3. bridges — child OUTPUT → navigation (the core `.on` bridge)
            bridges()
        ])
    }

    // Bridges — child OUTPUT actions become navigation, in one pattern-matching reducer.
    private static func bridges() -> Behavior<AppAction, AppState, World> {
        .reduce { action, state in
            switch action {
            case let .library(.tappedShelf(id)):
                state.path.append(.shelf(id)) // tap a shelf → push it

            case .book(.tappedEdit):
                if let book = state.book?.book {
                    state.editor = .presented(EditorFeature.initialState(with: book)) // "Edit" → present editor
                }

            case .editor(.child(.tappedSave)), .editor(.child(.tappedCancel)):
                state.editor = state.editor.dismiss() // begin dismiss; SwiftUI's onDismiss finishes it

            case let .openedURL(url): // deep link → navigation is just state
                if let id = bookID(from: url) { state.tab = .library; state.path = [.book(id)] }

            default:
                break
            }
        }
    }
}
```

> A plain pattern-matching reducer is the clearest way to turn a child *output* into navigation. For a pure route→re-dispatch with no state (e.g. a logout button that fires an auth action), the core `.on(.action(…), dispatch: .action(…))` bridge does the same in one line. The editor's `dismiss()` here is the **programmatic** first step (`presented → dismissing`); SwiftUI's `onDismiss` supplies the second (Layer 6).

## Layer 5 — Scopes: declare the wiring once

A ``Relay/Scope`` bundles `(action prism, state key path, env narrow)` and drives both a child's lifted `.behavior(of:)` and its `.view(of:from:world:)`. Declare each scope once — the ``ScopeOf`` entry pins `AppFeature`'s triad, so every key-path root infers:

```swift
public enum AppScopes {
    public static let library = ScopeOf<AppFeature>
        .action(\.library) // a PRESENT sibling slice → a clean total lift
        .state(\.library)
        .environment { world in LibraryFeature.Environment(loadShelves: world.loadShelves) }
}
```

`AppScopes.library.behavior(of: LibraryFeature.self)` folds into Layer 4; `AppScopes.library.view(of: LibraryFeature.self, from:, world:)` is called by the router (Layer 6). The literal is a **compile-time proof**: a wrong slot, case, or env mapping won't type-check.

> **Only present-state children lift with a total state key path.** A total `WritableKeyPath` to the child state fits the *selection* siblings and the library — and only such a scope can build a view with `.view(of:from:world:)`. An **optional** child (`book: BookFeature.State?`) or a **presentation** child (`editor: Presentation<…>`) has no such key path: its behavior lifts with an **affine** state lane (`.state(\.book)`, an optional key path) or `liftPresentation` (Layer 4), and its *view* is built where it's rendered — the router, or the sheet's content — with the view store's `traverse(.action(…).state(…))`. That maps the view store through the scope and swaps the nesting: a store of `Child?` (or `Presentation<Child>`) becomes an optional store of `Child` — a pure stage the child's feature view keeps its own view store over. The caller depends only on whether the child is there, so the frame where the slot is empty simply renders nothing — no placeholder (Layer 6). Same store, same wiring, one level in.

## Layer 6 — The Router and the Views (all four bindings)

The **router** holds the app's *view store* and the world and resolves a route to `some View`, handing each child feature a pure stage and supplying its environment (which an env-free view body can't). Navigation reads state in a view body, so it goes through a `ViewStore` — the binding and `traverse` helpers don't even exist on the plain `Store`:

```swift
@MainActor struct AppRouter {
    let store: AppViewStore // the app's view store, kept by the shell with @OwnedStore (Layer 7)
    let world: World

    @ViewBuilder func view(for route: AppRoute) -> some View {
        switch route {
        case .shelf: AppScopes.library.view(of: LibraryFeature.self, from: store, world: world) // (a real app wires a ShelfFeature)
        case .book: bookView()
        }
    }

    @ViewBuilder private func bookView() -> some View {
        // The optional `book` slice, mapped through its scope and swapped into an optional store — build the child
        // only while it's present (a real app loads `state.book` when `.book(id)` is pushed); the empty frame
        // renders nothing. The router depends on the presence edge only, not on the book's contents.
        if let book = store.traverse(.action(\.book).state(\.book)) {
            BookFeature.view(store: book, environment: BookFeature.Environment())
        }
    }
}
```

The **root view** receives the app's view store and wires **selection** (tabs), **stack** (path) and **presentation** (the editor — an app-level slot, so it's presented where the app's view store is); the book's own view wires **optional** (the delete alert) on the book's view store:

```swift
struct RootView: View, Routable {
    let viewStore: AppViewStore // received — a plain let
    let router: AppRouter

    var body: some View {
        TabView(selection: viewStore.binding(.state(\.tab).action(review: { AppAction.tab(.select($0)) }))) { // SELECTION
            NavigationStack(path: viewStore.binding(.state(\.path).action(review: { AppAction.nav(.setPath($0)) }))) { // STACK
                AppScopes.library.view(of: LibraryFeature.self, from: viewStore, world: router.world)
                    .navigationDestination(for: AppRoute.self) { router.view(for: $0) }
            }
            .tabItem { Label("Library", systemImage: "books.vertical") }
            .tag(Tab.library)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        // PRESENTATION — a Binding<Presentation> wires both dismiss edges:
        .sheet(item: viewStore.binding(.state(\.editor).action(\.editor))) { _ in
            // Map through the slot's child lane (`.editor(.child(_))`) and the `Presentation<…>` state, then swap:
            // live through both `presented` and `dismissing(last:)`, `nil` only once dismissed — no flicker.
            if let editor = viewStore.traverse(.action(\.editor.child).state(\.editor)) {
                EditorFeature.view(store: editor, environment: router.world.editorEnv)
            }
        }
    }
}

@BoundTo(BookFeature.self)
struct BookView: View {
    // injected: let viewStore: ViewStore<BookFeature.Action, BookFeature.State>
    var body: some View {
        Form { Text(viewStore.state.book.title) }
            .toolbar { Button("Edit") { viewStore.dispatch(.tappedEdit) } }
            // OPTIONAL — a delete confirmation; the optional is both "is it shown" and "what it shows":
            .alert(
                "Delete book?",
                isPresented: viewStore.binding(.state(\.deleting).action(\.cancelDelete)),
                presenting: viewStore.state.deleting.value
            ) { book in
                Button("Delete \(book.title)", role: .destructive) { viewStore.dispatch(.confirmDelete) }
                Button("Cancel", role: .cancel) { viewStore.dispatch(.cancelDelete) }
            }
    }
}
```

`BookView` is `BookFeature`'s `Content`: the generated `BookFeature.view(store:environment:)` keeps the book's view store and hands it in, so the view never sees the app types — "Edit" is an output the app bridges into the editor presentation (Layer 4).

`binding(.state(\.editor).action(\.editor))` on a `Presentation` slot gives a `Binding<Presentation<…>>`: `.sheet(item:)` takes it directly when the value is `Identifiable` (`EditorFeature.State` is), and for any other container use its parts — `.fullScreenCover(isPresented: editor.isPresented(), onDismiss: editor.onDismiss())`. On an optional slot, `binding(.state(\.deleting).action(\.cancelDelete))` gives the `Binding<Bool>` or `Binding<Item?>` the SwiftUI parameter asks for.

## Layer 7 — The `@main` assembly (store, scene, deep link)

The real store is created once, at launch, and runs the whole tree; one view store follows it, owned by the shell view. The deep link is an *action source* — turn the URL into an action; the reducer sets navigation state:

```swift
public typealias AppViewStore = ViewStore<AppAction, AppState>

@main struct BookshelfApp: App {
    let world = World.live
    // The real store: created once, it runs the app and is never observed.
    let store: Store<AppAction, AppState, World>

    init() {
        store = Store(initial: AppState(), behavior: AppFeature.behavior(world: world), environment: world)
    }

    var body: some Scene {
        WindowGroup {
            AppShell(store: store, world: world)
                .onOpenURL { store.dispatch(.openedURL($0)) } // deep link → action on the real store (reduced in Layer 4)
        }
    }
}

// The leaf: one view store following the real store, owned here; everything below receives it.
struct AppShell: View {
    @OwnedStore var viewStore: AppViewStore
    let world: World

    init(store: Store<AppAction, AppState, World>, world: World) {
        _viewStore = OwnedStore(wrappedValue: store.viewStore())
        self.world = world
    }

    var body: some View {
        RootView(viewStore: viewStore, router: AppRouter(store: viewStore, world: world))
    }
}
```

The URL never navigates directly — `onOpenURL` turns it into `.openedURL`, and the bridges reducer (Layer 4) sets `tab` + `path`. Navigation is a function of state, so a deep link is just another action that writes it.

## Recap — shape × layer

| Shape | State | Action | Behavior (Layer 4) | Binding (Layer 6) | Container |
|---|---|---|---|---|---|
| **Selection** | `tab: Tab` | `.tab(SelectionNavigation<Tab>)` | `.navigationSelection(\.tab, action: \.tab)` | `binding(.state(…).action(…))` | `TabView` / split |
| **Stack** | `path: [AppRoute]` | `.nav(StackNavigation<AppRoute>)` | `.navigationStack(\.path, action: \.nav)` | `binding(.state(…).action(…))` | `NavigationStack(path:)` |
| **Presentation** | `editor: Presentation<…>` | `.editor(PresentationAction<…>)` | `.liftPresentation(action: \.editor, state: \.editor, …)` | `binding(.state(…).action(…))` → `Binding<Presentation<…>>` | sheet / cover |
| **Optional** | `deleting: Book?` | `.book(.tappedDelete/…)` | `.navigationItem(…)` or a plain reducer | `binding(.state(…).action(…))` → `Binding<Bool>` / `Binding<Item?>` | alert / sheet / popover |

Every one is the same recipe: **store the shape in state, dispatch through an action, fold a reducer/lift for it, bind a native container to it, resolve destinations through the router.** No new dialect — just state, actions, and `some View`.

## See Also

- <doc:Navigation>
- <doc:Features>
- <doc:Lifting>
- ``Relay/Scope``
- <doc:StoresAtAGlance>
