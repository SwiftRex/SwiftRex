# Navigation, End to End

Build one small app — **Bookshelf** — and wire every navigation shape across every layer: domain, features, the global feature, the behavior fold, scopes, the router, the views, and the `@main` assembly.

## Overview

<doc:Navigation> is the reference — the four state shapes and every container, by shape. This article is the *follow-along*: one app that uses all of them together, shown top to bottom so you can copy the whole stack, not a snippet.

**Bookshelf** has:

```
TabView  (selection)  ─┬─  Library tab
                       │      └─ NavigationStack (stack):  Shelves ─▶ Books ─▶ Book
                       │            └─ Book: "Edit" ─▶ Editor      (presentation modal)
                       │                    "Delete" ─▶ confirm    (optional / Bool)
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
@Feature(strategy: .observationSimple)
public enum LibraryFeature {
    public struct State: Sendable, Equatable { public var shelves: [Shelf] = [] }
    public enum Action: Sendable { case onAppear; case loaded([Shelf]); case tappedShelf(Shelf.ID) }
    public struct Environment: Sendable { public var loadShelves: @Sendable () -> Publisher<[Shelf], Never> }

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, _ in
            switch action {
            case .onAppear:      .produce { ctx in ctx.environment.loadShelves().asEffect(Action.loaded) }
            case let .loaded(s):  .reduce { $0.shelves = s }
            case .tappedShelf:    .doNothing   // OUTPUT — the app bridges this into a push (Layer 4)
            }
        }
    }
    public typealias Content = LibraryView
}

// BookFeature — a single book; owns "edit" + "delete" intents (a module entry point).
@Feature(strategy: .observationSimple)
public enum BookFeature {
    public struct State: Sendable, Equatable { public var book: Book; public var confirmingDelete = false }
    public enum Action: Sendable { case tappedEdit; case tappedDelete; case confirmDelete; case cancelDelete }
    public struct Environment: Sendable {}

    public static func behavior() -> Behavior<Action, State, Environment> {
        .reduce { action, state in
            switch action {
            case .tappedDelete:  state.confirmingDelete = true
            case .cancelDelete:  state.confirmingDelete = false
            case .tappedEdit, .confirmDelete: break   // OUTPUT — bridged by the app (Layer 4)
            }
        }
    }
    public typealias Content = BookView
}

// EditorFeature — the modal editor (a module entry point).
@Feature(strategy: .observationSimple)
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
            case .tappedSave, .tappedCancel: break   // OUTPUT — bridged to dismiss (Layer 4)
            }
        }
    }
    public typealias Content = EditorView
}
```

> `EditorFeature.State` is `Identifiable` (by the book's id) — that stable id is what lets it drive a `.sheet(item:)` without churning identity (Layer 6).

## Layer 3 — The global feature: where every shape is *stored*

The whole app is one ``FeatureDomain`` — the parent that scopes hang off. Its `State`/`Action`/`Environment` is where each navigation shape lives. **This is the "how do I store this" answer:**

```swift
// AppFeature — the parent FeatureDomain. `Relay.Scope` (declared in `AppScopes`) embeds each child here.
public enum AppFeature: FeatureDomain {
    public typealias Action = AppAction
    public typealias State = AppState
    public typealias Environment = World
}

@Lenses
public struct AppState: Sendable, Equatable {
    // selection shape  → a plain value
    public var tab: Tab = .library
    // stack shape      → an ordered array of routes
    public var path: [AppRoute] = []
    // presentation shape → the three-stage lifecycle
    public var editor: Presentation<EditorFeature.State> = .dismissed
    // the feature state slices (present siblings, always alive)
    public var library = LibraryFeature.State()
    public var book: BookFeature.State?          // optional: only while a book is on the stack
}

@Prisms
public enum AppAction: Sendable {
    // one nav-operation case per shape (payload enums from SwiftRex.Architecture)
    case tab(SelectionNavigation<Tab>)           // .select(tab)
    case nav(StackNavigation<AppRoute>)          // .push / .pop / .popToRoot / .setPath
    case editor(PresentationAction<EditorFeature.Action>)  // .dismiss / .child — no State in the action
    // the child features' own actions
    case library(LibraryFeature.Action)
    case book(BookFeature.Action)
    case openedURL(URL)                          // deep link in
}
```

| Shape | Stored in `AppState` as | Driven by `AppAction` case |
|---|---|---|
| Selection (tabs) | `tab: Tab` | `.tab(SelectionNavigation<Tab>)` |
| Stack (push path) | `path: [AppRoute]` | `.nav(StackNavigation<AppRoute>)` |
| Presentation (editor modal) | `editor: Presentation<EditorFeature.State>` | `.editor(PresentationAction<…>)` |
| Optional (delete alert) | `book.confirmingDelete: Bool` (inside the book slice) | `.book(.tappedDelete/.cancelDelete)` |

## Layer 4 — `behavior()`: fold the features + drive the shapes

The app behavior is a monoid fold of: each child's **lifted** behavior, one reducer **per navigation shape**, and **bridges** that turn child outputs into navigation.

```swift
public extension AppFeature {
    static func behavior(world: World) -> Behavior<AppAction, AppState, World> {
        Behavior.combine([
            // 1. children, lifted to the app types
            AppScopes.library.behavior(of: LibraryFeature.self),                                   // present sibling → plain lift
            BookFeature.behavior().lift(.action(AppAction.prism.book).state(\.book)
                .environment { _ in .init() }),  // optional \.book → affine state: runs only while on the stack
            EditorFeature.behavior().liftPresentation(action: \.editor, state: \.editor,
                                                      environment: { $0.editorEnv }),  // presentation stage machine + child

            // 2. one reducer per navigation shape (from SwiftRex.Architecture)
            .navigationSelection(\.tab,  action: \.tab),                     // selection
            .navigationStack(\.path,     action: \.nav),                     // stack: push/pop/setPath

            // 3. bridges — child OUTPUT → navigation (the core `.on` bridge)
            bridges()
        ])
    }

    // Bridges — child OUTPUT actions become navigation, in one pattern-matching reducer.
    private static func bridges() -> Behavior<AppAction, AppState, World> {
        .reduce { action, state in
            switch action {
            case let .library(.tappedShelf(id)):
                state.path.append(.shelf(id))                       // tap a shelf → push it

            case .book(.tappedEdit):
                if let book = state.book?.book {
                    state.editor = .presented(EditorFeature.initialState(with: book))   // "Edit" → present editor
                }

            case .editor(.child(.tappedSave)), .editor(.child(.tappedCancel)):
                state.editor = state.editor.dismiss()               // begin dismiss; SwiftUI's onDismiss finishes it

            case let .openedURL(url):                               // deep link → navigation is just state
                if let id = bookID(from: url) { state.tab = .library; state.path = [.book(id)] }

            default:
                break
            }
        }
    }
}
```

> A plain pattern-matching reducer is the clearest way to turn a child *output* into navigation. For a pure route→re-dispatch with no state (e.g. a logout button that fires an auth action), the point-free ``Behavior/on(_:dispatch:)`` bridge does the same in one line. The editor's `dismiss()` here is the **programmatic** first step (`presented → dismissing`); SwiftUI's `onDismiss` supplies the second (Layer 6).

## Layer 5 — Scopes: declare the wiring once

A ``Relay/Scope`` bundles `(action prism, state key path, env narrow)` and drives both a child's lifted `.behavior(of:)` and its `.view(of:from:world:)`. Declare each scope once — an explicit action prism pins the parent's action type, so the scope's type infers:

```swift
public enum AppScopes {
    public static let library = Relay.Empty
        .action(AppAction.prism.library)     // a PRESENT sibling slice → a clean total lift
        .state(\AppState.library)
        .environment { world in LibraryFeature.Environment(loadShelves: world.loadShelves) }
}
```

`AppScopes.library.behavior(of: LibraryFeature.self)` folds into Layer 4; `AppScopes.library.view(of: LibraryFeature.self, from:, world:)` is called by the router (Layer 6). The literal is a **compile-time proof**: a wrong slot, case, or env mapping won't type-check.

> **Only present-state children lift with a total state key path.** A total `WritableKeyPath` to the child state fits the *selection* siblings and the library. An **optional** child (`book: BookFeature.State?`) or a **presentation** child (`editor: Presentation<…>`) has no such key path: its behavior lifts with an **affine** state lane (`.state(\.book)`, an optional key path) or `liftPresentation` (Layer 4), and its *view* is built where it's rendered — the router or the `.presenting` content — by ``StoreType/transpose()``, which inverts a `Store<Child?>` (or `Store<Presentation<Child>>`) into an `Optional<Store<Child>>` so the frame where the slot is empty simply renders nothing — no placeholder (Layer 6). Same store, same wiring, one level in.

## Layer 6 — The Router and the Views (all four bindings)

The **router** holds the store and the world and resolves a route to `some View`, supplying each child's environment (which an env-free view body can't):

```swift
@MainActor struct AppRouter {
    let store: MainStore
    let world: World

    @ViewBuilder func view(for route: AppRoute) -> some View {
        switch route {
        case .shelf: AppScopes.library.view(of: LibraryFeature.self, from: store, world: world)   // (a real app wires a ShelfFeature)
        case let .book(id): bookView(id)
        }
    }
    @ViewBuilder private func bookView(_ id: Book.ID) -> some View {
        // The optional `book` slice transposes to `Optional<Store>` — build the child only while it's
        // present (a real app loads `state.book` when `.book(id)` is pushed); the empty frame renders nothing.
        if let child = store.projection(.action(AppAction.prism.book).state(\.book)).transpose() {
            BookFeature.view(store: child, environment: .init())
        }
    }
}
```

The **root view** wires **selection** (tabs) and **stack** (path); the book view wires **presentation** (editor) and **optional** (delete alert):

```swift
struct RootView: View {
    let store: MainStore
    let router: AppRouter

    var body: some View {
        TabView(selection: store.binding(.state(\.tab), dispatch: .action(review: { AppAction.tab(.select($0)) }))) {   // SELECTION
            NavigationStack(path: store.binding(.state(\.path), dispatch: .action(review: { AppAction.nav(.setPath($0)) }))) {   // STACK
                AppScopes.library.view(of: LibraryFeature.self, from: store, world: router.world)
                    .navigationDestination(for: AppRoute.self) { router.view(for: $0) }
            }
            .tabItem { Label("Library", systemImage: "books.vertical") }.tag(Tab.library)

            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(Tab.settings)
        }
    }
}

struct BookView: View, Routable {
    let viewStore: ViewStore<BookFeature.State, BookFeature.Action>
    let router: AppRouter

    var body: some View {
        Form { Text(viewStore.state.book.title) }
            .toolbar { Button("Edit") { viewStore.dispatch(.tappedEdit) } }
            // PRESENTATION — the modifier wires both dismiss edges; content is live from the store:
            .presenting(router.store, \.editor, dismiss: .editor(.dismiss)) { _ in
                // Project the slot's action (`.editor(.child(_))`) + the `Presentation<…>` state, then
                // `transpose()` inverts `Store<Presentation<Editor>>` into `Store<Editor>?` — live through
                // both `presented` and `dismissing(last:)`, `nil` only once dismissed, so no flicker:
                if let editor = router.store
                    .projection(action: { AppAction.editor(.child($0)) }, state: { $0.editor })
                    .transpose() {
                    EditorFeature.view(store: editor, environment: router.world.editorEnv)
                }
            }
            // OPTIONAL / Bool — a delete confirmation:
            .alert("Delete book?", isPresented: viewStore.presence(.state(\.confirmingDelete), dismiss: .cancelDelete)) {
                Button("Delete", role: .destructive) { viewStore.dispatch(.confirmDelete) }
                Button("Cancel",  role: .cancel)      { viewStore.dispatch(.cancelDelete) }
            }
    }
}
```

Prefer ``StoreType/presence(_:dismiss:)`` (the `Bool` binding, above) as the default; reach for ``StoreType/item(_:dismiss:)`` + `.presentingItem` only when a `.sheet(item:)` genuinely needs the `Identifiable` value (`EditorFeature.State` is `Identifiable`, so it qualifies).

## Layer 7 — The `@main` assembly (store, scene, deep link)

The store is created once, at launch, and owns the whole tree. The deep link is an *action source* — turn the URL into an action; the reducer sets navigation state:

```swift
public typealias MainStore = Store<AppAction, AppState, World>

@main struct BookshelfApp: App {
    let store: MainStore
    let router: AppRouter

    init() {
        let world = World.live
        let store = Store(initial: AppState(), behavior: AppFeature.behavior(world: world), environment: world)
        self.store = store
        self.router = AppRouter(store: store, world: world)
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, router: router)
                .onOpenURL { store.dispatch(.openedURL($0)) }   // deep link → action (reduced in Layer 4)
        }
    }
}
```

The URL never navigates directly — `onOpenURL` turns it into `.openedURL`, and the bridges reducer (Layer 4) sets `tab` + `path`. Navigation is a function of state, so a deep link is just another action that writes it.

## Recap — shape × layer

| Shape | State | Action | Behavior (Layer 4) | Binding (Layer 6) | Container |
|---|---|---|---|---|---|
| **Selection** | `tab: Tab` | `.tab(SelectionNavigation<Tab>)` | `.navigationSelection(\.tab, action: \.tab)` | ``StoreType/binding(_:dispatch:)`` | `TabView` / split |
| **Stack** | `path: [AppRoute]` | `.nav(StackNavigation<AppRoute>)` | `.navigationStack(\.path, action: \.nav)` | ``StoreType/binding(_:dispatch:)`` | `NavigationStack(path:)` |
| **Presentation** | `editor: Presentation<…>` | `.editor(PresentationAction<…>)` | `.liftPresentation(action: \.editor, state: \.editor, …)` | ``StoreType/presence(_:dismiss:)`` + `.presenting` | sheet / cover |
| **Optional** | `confirmingDelete: Bool` | `.book(.tappedDelete/…)` | `.navigationItem(…)` or a plain reducer | ``StoreType/presence(_:dismiss:)`` / ``StoreType/item(_:dismiss:)`` | alert / sheet / popover |

Every one is the same recipe: **store the shape in state, dispatch through an action, fold a reducer/lift for it, bind a native container to it, resolve destinations through the router.** No new dialect — just state, actions, and `some View`.

## See Also

- <doc:Navigation>
- <doc:Features>
- <doc:Lifting>
- ``Relay/Scope``
- ``Presentation``
- ``StoreType/transpose()``
