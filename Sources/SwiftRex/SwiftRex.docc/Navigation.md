# State-Driven Navigation

Model navigation as a function of state: routes live in state, SwiftUI bindings dispatch, and a router builds destination views — resolving the environment that an env-free view body can't.

## Overview

Navigation in SwiftRex is **pure SwiftUI Views reacting to state**. There is one store for the whole app; a view reads it through a view store (a `ViewStore`, granular per key path — see <doc:StoresAtAGlance>). Behavior mutates the navigation *state* (a route, an optional, a path, a selection); it never touches the view or the router. Every SwiftUI navigation container — sheet, cover, popover, alert, dialog, inspector, `NavigationStack`, `NavigationSplitView`, `TabView`, pages, windows — is just a pluggable *rendering* of one of four state **shapes**:

| Shape | State | Lift | Binding | Reducer |
| --- | --- | --- | --- | --- |
| **Optional / modal** — 0-or-1, child created on present | `Item?` | `lift` through an affine `.state(\.x)` / `liftOptional` | `binding(.state(\.x).action(\.close))` → `Binding<Item?>` / `Binding<Bool>` | `Behavior.navigationItem(_:action:allow:)` |
| **Stack** — 0-to-N ordered | `[Route]` | `liftCollection` | `binding(.state(\.x).action(\.setX))` | `Behavior.navigationStack(_:action:allow:)` |
| **Selection** — exactly 1-of-N, all alive | `Sel` (enum/id) | plain `lift` ×N | `binding(.state(\.x).action(\.setX))` | `Behavior.navigationSelection(_:action:allow:)` |
| **Scene set** — 0-to-N windows | keyed sub-states | `liftCollection` (`.state(dictionary:)`) | `traverse(_:element:)` / `hasScene(_:in:)` + `WindowGroup(for:)` | ordinary open/close actions |

The rest is: pick the shape, drive its binding, resolve the destination through a router. No new dialect — the bindings feed *native* SwiftUI modifiers. The bindings live on the **view store** (`ViewStore`) — on a plain `Store` or a projection they don't compile, because SwiftUI couldn't observe them. Every snippet below runs inside a view that has the view store as `viewStore` (kept with `@OwnedStore`, or received as a plain `let`) and a `router`.

> This page is the **reference** — each shape and container in isolation. For one app that wires all four shapes across every layer (domain → features → the global feature → behavior fold → scopes → router → views → `@main`), with the full stack shown, follow <doc:NavigationEndToEnd>.

## Every container, by shape

### Optional / modal — `Item?`

Presentation and child lifetime are one fact: set the optional and the child exists and shows; clear it and it tears down. Model the presentation as the **optional content** itself — never a `Bool` flag beside it: one value says both *whether* it shows and *what* it shows, so the two can't disagree. Then bind it with the one binding form, `binding(.state(\.slot).action(\.dismiss))` — the optional slot and a no-payload dismiss case. It gives whichever binding the modifier asks for: a `Binding<Item?>` for `item:` parameters (the content is `Identifiable`), or a `Binding<Bool>` for `isPresented:` ones, `true` while the optional is `.some` (pass the content through `presenting:` where the modifier takes it). Either only ever dispatches the *dismiss* action — presentation is driven by state, never by the binding.

```swift
// Every `\.slot` below is an OPTIONAL holding the content (`onboarding: Onboarding.State?`, `tip: Tip?`, …).
// Sheet, full-screen cover, popover — item- or isPresented-driven, interchangeably:
.sheet(item: viewStore.binding(.state(\.editing).action(\.dismissEditor))) { item in router.view(for: .editor(item.id)) }
.fullScreenCover(isPresented: viewStore.binding(.state(\.onboarding).action(\.finishOnboarding))) { router.view(for: .onboarding) }
.popover(item: viewStore.binding(.state(\.tip).action(\.dismissTip))) { tip in TipView(tip) }

// Bottom sheet — a sheet whose content carries detents:
.sheet(isPresented: viewStore.binding(.state(\.filters).action(\.closeFilters))) {
    router.view(for: .filters).presentationDetents([.medium, .large])
}

// Inspector (iOS 17+) — `isPresented:`-driven, over the optional inspected value:
.inspector(isPresented: viewStore.binding(.state(\.inspector).action(\.hideInspector))) { router.view(for: .inspector) }

// Single push via NavigationStack, without a path:
.navigationDestination(isPresented: viewStore.binding(.state(\.detail).action(\.popDetail))) { router.view(for: .detail) }

// Alert / confirmation dialog — present with a dismiss-only binding; the BUTTONS dispatch their own actions:
.alert(
    "Delete?",
    isPresented: viewStore.binding(.state(\.deleteConfirm).action(\.cancelDelete)),
    presenting: viewStore.state.deleteConfirm.value
) { item in
    Button("Delete", role: .destructive) { viewStore.dispatch(.confirmDelete(item.id)) }
    Button("Cancel", role: .cancel) { viewStore.dispatch(.cancelDelete) }
}
.confirmationDialog("Sort", isPresented: viewStore.binding(.state(\.sortDialog).action(\.closeSort))) {
    Button("Newest") { viewStore.dispatch(.sort(.newest)) }
    Button("Oldest") { viewStore.dispatch(.sort(.oldest)) }
}
```

Behavior side: lift the child through an optional state key path (`.state(\.slot)`, an affine lane — the child runs only while `.some`), and `Behavior.navigationItem(_:action:allow:)` for standard present/dismiss with an optional veto.

#### `Presentation` — model the dismissal frame instead of hacking it

`Item?` is *two* states (shown / gone), but a dismiss is *three*: shown, **animating-out-still-showing-the-last-value**, gone. Squeezing that middle state out is what forces the ugly `?? .placeholder` (content blanks as it slides away) or a view-layer latch. `Presentation` names it — `presented(x)` / `dismissing(last: x)` / `dismissed` — exactly as `Loading` names `reloading(previous:)`. It's a **pure** state type (a plain enum — no view, no timer): the store stays the single source of truth, no latch.

```swift
struct State { var editor: Presentation<Editor.State> = .dismissed } // slot
enum Action { case editor(PresentationAction<Editor.Action>) } // dismiss / dismissed / child (present is a reducer)

// behavior — one lift folds present, the stage machine, and the child:
Editor.behavior().liftPresentation(.action(\.editor).state(\.editor).environment(\.editorEnv))

// view — a Binding<Presentation> carries BOTH dismiss edges, so the state can't get stuck mid-dismiss:
content.sheet(item: viewStore.binding(.state(\.editor).action(\.editor))) { _ in router.view(for: .editor) }
```

SwiftUI reports a dismissal twice, and so does `PresentationAction`: `.dismiss` when it *starts* (the binding goes `false`/`nil` — `presented → dismissing`) and `.dismissed` when the animation *ends* (`onDismiss`, a real SwiftUI completion, not a timer). `binding(.state(\.editor).action(\.editor))` on a `Presentation` slot returns a `Binding<Presentation<T>>` that carries both: `.sheet(item:)` takes it directly for an `Identifiable` value; for any other container take its parts — `.fullScreenCover(isPresented: editor.isPresented(), onDismiss: editor.onDismiss())`, or `.item()` for an `item:` parameter. There is deliberately no `Bool` binding straight from a `Presentation` slot: without `onDismiss` the slot would stay `dismissing`. Content renders the value carried by *both* live stages, so it stays put through the animation. The plain `Item?` bindings above remain the *simple* path when the dismissal flicker doesn't matter.

#### Building the child view — `traverse`

An optional-shaped destination is a slot holding an *optional* (`Child?`), but `Child.view(store:environment:)` wants a store of the *unwrapped* value. `traverse(scope)` maps the view store through the scope and swaps the nesting — a store of `Child?` becomes an optional store of `Child` (a `StoreOptionalFocus`, or `nil`) — so the child store exists exactly when its state is present. (`transpose()`, with no arguments, is the swap alone — for a view store whose *own* state is `T?` or `Presentation<T>`.) The caller depends only on that **presence edge**: it redraws when the child appears or disappears, never when something inside the child changes. What comes back is a pure stage; the child feature's view keeps its own view store over it.

```swift
// Optional child slice — map through the scope, then swap:
if let child = viewStore.traverse(.action(\.child).state(\.child)) {
    Detail.view(store: child, environment: world.detailEnv)
}

// A lane no key path expresses (an affine `preview`, the top of a stack, an enum case):
if let screen = viewStore.traverse(action: { .detail($0) }, state: { $0.path.last?.detail }) {
    Detail.view(store: screen, environment: world.detailEnv)
}
```

For the `Presentation` shape, `traverse` reads the live child through **both** `presented` and `dismissing(last:)`, going `nil` only once `dismissed` — the child store (and its view) stay alive and steady while SwiftUI animates the sheet out, so building a destination this way is flicker-free without any view-layer latch:

```swift
if let editor = viewStore.traverse(.action(\.editor.child).state(\.editor)) { // state: Presentation<Editor.State>
    Editor.view(store: editor, environment: world.editorEnv)
}
```

A list of rows that dispatch iterates with `each(scope)` — the same collection scope a projection takes, with the action lane into an `ElementAction<ID, RowAction>` case. The list depends on the ids only; each item is a pure stage the row's feature view keeps its own view store over:

```swift
List(viewStore.each(.action(\.row).state(\.rows))) { row in
    Row.view(store: row, environment: world.rowEnv)
}
```

For one element outside a loop, `viewStore.traverse(.action(\.row).state(\.rows), element: id)` returns the same stage, or `nil` once the element is gone. A list whose rows only *display* needs no row stores at all — `viewStore.state.each(\.rows)` gives one position per element.

Each row store is a pure stage (``StoreCollectionFocus`` under ``StoreOptionalFocus``): the row view's own view store redraws only for its own element. It dispatches `RowAction` as `.row(ElementAction(id, action))`, finds its element through a hint of its own (O(distance moved)), and holds its last value while it animates out. The list holds nothing for it, and nothing is asked of the state: a plain array of `Identifiable` values.

> Note: `traverse` and `transpose()` read the presence edge synchronously in a body, so they live on `ViewStore`. Outside SwiftUI, presence is plain state — follow `stateStream.map { $0.child != nil }.removeDuplicates()` and present or dismiss on the edge. The forms above depend on the presence edge only, never on the child's contents.

### Stack — `[Route]`

`NavigationStack(path:)` reflects the whole path; SwiftUI hands the binding the new path on any change, so one `setPath` action covers push, back-swipe, and pop-to-root. Destinations resolve through the router.

```swift
NavigationStack(path: viewStore.binding(.state(\.path).action(review: NavAction.setPath))) {
    HomeScreen(...)
        .navigationDestination(for: AppRoute.self) { route in router.view(for: route) }
}
```

Behavior side: `liftCollection` per element, plus `Behavior.navigationStack(_:action:allow:)` for `push`/`pop`/`popToRoot`/`setPath` (veto e.g. a pop while a form is dirty).

### Selection — 1-of-N, all children alive

Tabs, split view, and paged/carousel views keep every child mounted; only the selection changes. All children are lifted **unconditionally** (siblings in state). Unlike modal dismiss, selecting is a normal state change, so the two-way binding dispatches on every change (for an `Equatable` value it skips a write equal to the current one — SwiftUI sometimes writes a selection twice per tap).

```swift
// Tabs:
TabView(selection: viewStore.binding(.state(\.tab).action(review: AppAction.selectTab))) {
    router.view(for: .home).tag(Tab.home)
    router.view(for: .search).tag(Tab.search)
}

// Paged / carousel — same selection, page style:
TabView(selection: viewStore.binding(.state(\.page).action(review: AppAction.selectPage))) { … }
    .tabViewStyle(.page)

// Split view — selection + column visibility (the latter is just a plain `binding`):
NavigationSplitView(columnVisibility: viewStore.binding(.state(\.columns).action(review: AppAction.setColumns))) {
    Sidebar(selection: viewStore.binding(.state(\.selectedItem).action(review: AppAction.select))) // optional selection
} detail: {
    router.view(for: .detail)
}
```

> A background/unselected child keeps running by default (that's the point of tabs). To pause one, add a supervisor keyed on the selection — it's your policy, not a framework default.

### Scene set — windows, one store

Multiple windows are still one store. Model open scenes as state (a dictionary of per-scene sub-states); each window keeps its own view store over the one real store and traverses to its slice by id; open/close are ordinary actions.

```swift
@main struct DocsApp: App {
    let world = World.live
    let store: Store<AppAction, AppState, World> // the real store — a plain `let`, never observed

    init() {
        store = Store(initial: AppState(), behavior: AppFeature.behavior(), environment: world)
    }

    var body: some Scene {
        WindowGroup { AppFeature.view(store: store, environment: world) }
        WindowGroup(for: DocID.self) { $id in
            if let id { DocumentWindow(store: store, world: world, id: id) }
        }
        // `Settings`, `MenuBarExtra`, `Window` follow the same single-store pattern.
    }
}

// `documents: [DocID: Document.State]`, `case document(ElementAction<DocID, Document.Action>)`.
struct DocumentWindow: View {
    @OwnedStore var viewStore: ViewStore<AppAction, AppState>
    let world: World
    let id: DocID

    init(store: some StoreType<AppAction, AppState>, world: World, id: DocID) {
        _viewStore = OwnedStore(wrappedValue: store.viewStore())
        self.world = world
        self.id = id
    }

    var body: some View {
        if let document = viewStore.traverse(.action(\.document).state(dictionary: \.documents), element: id) {
            Document.view(store: document, environment: world.docEnv)
        }
    }
}
```

The window depends on its scene's presence only. `viewStore.hasScene(id, in: \.documents)` answers the same question as a `Bool` — for a window body that calls `dismissWindow` once its scene's state is gone.

`openWindow(value: DocID(…))` / `dismissWindow` are triggered by dispatching actions that add or remove a scene's sub-state — the window set is a function of state.

### System & UIKit content — share sheet, pickers, web, Safari

Interruptive system UI and UIKit screens aren't a new shape — they're the **optional/modal** shape with a `UIViewControllerRepresentable`/`UIViewRepresentable` as the presented *content*. State drives *whether* it shows (the dismiss-only binding, as always); the representable's `Coordinator` dispatches actions back for its results, so an outcome flows in as an ordinary action.

```swift
.sheet(item: viewStore.binding(.state(\.sharing).action(\.doneSharing))) { payload in
    ActivityView(items: payload.items) // UIViewControllerRepresentable(UIActivityViewController)
}
.sheet(isPresented: viewStore.binding(.state(\.picker).action(\.cancelPicker))) {
    PhotoPicker { images in viewStore.dispatch(.picked(images)) } // Coordinator dispatches the result
}
.fullScreenCover(item: viewStore.binding(.state(\.browsing).action(\.closeBrowser))) { page in
    WebView(url: page.url) // WKWebView / SwiftUI WebView, or SFSafariViewController
}
```

The rule is unchanged: presentation is a function of state (the binding only *dismisses*); UIKit *results* come back as actions via the representable's `Coordinator` → `viewStore.dispatch`. A web view's own in-page back/forward is the web view's business — if you want it in state, that's just the web feature's `State`. `ShareLink` (a tap-to-share view with no presented state) needs none of this — use it directly.

## URLs — deep links in, external opens out

A URL is never a navigation *shape* by itself; it sits at one of two boundaries:

- **Incoming** (deep link / universal link) — an *action source*. Turn the URL into an action; the reducer sets navigation state; the app navigates like any other transition:
  ```swift
  // In the App's body — `store` is the real Store, kept as a plain `let`:
  AppFeature.view(store: store, environment: world).onOpenURL { store.dispatch(.openedURL($0)) }
  // reducer: case let .openedURL(url): state.path = route(for: url)
  ```
- **Outgoing** (open an external URL — Safari, Mail, Maps) — a *side effect*, not navigation: your app backgrounds, nothing is presented. Inject an `openURL` dependency in `World` and produce a fire-and-forget effect (pure and testable), or call SwiftUI's `@Environment(\.openURL)` from a button for a trivial case:
  ```swift
  // World: let openURL: @Sendable (URL) -> Void
  case .tappedSupport: .produce { ctx in Effect.fireAndForget { ctx.environment.openURL(supportURL) } }
  ```

## Relay.Scope — declare the wiring once, drive both sides

A ``Relay/Scope`` captures how a child feature embeds into the app store — action prism, state key path, environment narrowing — and drives **both** the child's lifted `.behavior(of:)` and its `.view(of:from:world:)`. Building one is a **compile-time proof** the feature is wired; a missing state slot, action case, or env mapping is a compile error at the literal.

```swift
// The wiring — declared once. `ScopeOf<AppFeature>` pins the app `Rig`'s triad, so every root infers.
enum AppScopes {
    static let settings = ScopeOf<AppFeature>
        .action(\.settings).state(\.settings).environment(\.settingsEnv) // settings: Settings.State
    static let onboarding = ScopeOf<AppFeature>
        .action(\.onboarding).state(\.onboarding).environment(\.onboardingEnv) // onboarding: Onboarding.State?
    static let editor = ScopeOf<AppFeature>
        .action(\.editor).state(\.editor).environment(\.editorEnv) // editor: Presentation<Editor.State>
}

AppScopes.settings.behavior(of: Settings.self) // Behavior<AppAction, AppState, World> — register it
AppScopes.settings.view(of: Settings.self, from: viewStore, world: world) // Settings' view, env supplied — from the router
```

The same `.view(of:from:world:)` builds the view for the other slot shapes, from the same declared scope that lifts the child's behavior — given the app's **view store**, since deciding presence is a read:

| Slot | Behavior | View — `F.Body` or `F.Body?` |
|---|---|---|
| total (`settings: Settings.State`) | `AppScopes.settings.behavior(of: Settings.self)` | `AppScopes.settings.view(of: Settings.self, from: viewStore, world: world)` |
| optional (`onboarding: Onboarding.State?`, affine `.state(\.onboarding)`) | `AppScopes.onboarding.behavior(of: Onboarding.self)` | `if let v = AppScopes.onboarding.view(of: Onboarding.self, from: viewStore, world: world) { v }` |
| `Presentation` (`editor: Presentation<Editor.State>` + `PresentationAction`) | `Editor.behavior().liftPresentation(AppScopes.editor)` | `AppScopes.editor.view(of: Editor.self, from: viewStore, world: world)` — present while `presented` or `dismissing` |

An optional or presented view depends only on the slot's presence edge and holds its last value while it animates away.

Register every scope's behavior in one place — the behaviors are a monoid, so fold them with ``Behavior/combine(_:)`` (or `<>`):

```swift
let appBehavior = Behavior.combine([
    AppScopes.home.behavior(of: Home.self),
    AppScopes.settings.behavior(of: Settings.self),
    Behavior.navigationStack(\.path, action: \.nav) // + navigation reducers, logging, …
])
let store = Store(initial: .init(), behavior: appBehavior, environment: world)
```

A child feature's `Feature` conformance is generated by `@Feature` — no hand-written `extension Settings: Feature {}` — with Swift inferring the associated types from the members the macro generates.

## Router — the WHAT (and the environment crux)

`Feature.view(store:environment:)` needs an environment, but a navigation destination runs inside the *environment-free* view body. A **router** — a value holding the app's view store and the world — resolves that: its `@ViewBuilder view(for:)` switch hands each child feature a pure stage, through `Relay.Scope`'s `.view(of:from:world:)` or `F.view(store:environment:)` directly, supplying the child's environment there. `some View` throughout — no `AnyView`.

```swift
@MainActor struct AppRouter {
    let store: ViewStore<AppAction, AppState> // received from the root view, which keeps it with @OwnedStore
    let world: World

    @ViewBuilder func view(for route: AppRoute) -> some View {
        switch route {
        case .settings:
            // a present slice — the scope projects the store and narrows the world: crux resolved
            AppScopes.settings.view(of: Settings.self, from: store, world: world)
        case .onboarding:
            // an optional slice — depends on its presence only; nothing renders while it's nil
            if let onboarding = AppScopes.onboarding.view(of: Onboarding.self, from: store, world: world) {
                onboarding
            }
        // … one case per route (`.detail`, `.editor(id)`, `.filters`, …)
        }
    }
}
```

The app view store is kept where the app's view starts: the app feature's hand-written `view(store:environment:)` returns a root view that makes it with `.viewStore()`, keeps it with `@OwnedStore`, and hands it — a plain `let` — to the router and the views below. (The `App` itself keeps the real `Store` as a plain `let`; it is never observed.)

```swift
extension AppFeature {
    @MainActor static func view(store: any StoreType<AppAction, AppState>, environment: World) -> some View {
        AppRoot(store: store, world: environment)
    }
}

struct AppRoot: View {
    @OwnedStore var viewStore: ViewStore<AppAction, AppState>
    let world: World

    init(store: any StoreType<AppAction, AppState>, world: World) {
        _viewStore = OwnedStore(wrappedValue: store.viewStore())
        self.world = world
    }

    var body: some View {
        RootView(viewStore: viewStore, router: AppRouter(store: viewStore, world: world))
    }
}
```

A navigating view conforms to `Routable` and holds its router as a `let`, handed in at construction. Because the router builds every view, it re-hands itself at each construction — deterministic across the sheet/modal boundaries where SwiftUI's `@Environment` propagation is unreliable. The view body stays environment-free, and never names the child — the router does, so a route may resolve to a completely separate module (its own store slice and dependencies) without the presenting view importing it.

```swift
struct RootView: View, Routable {
    let viewStore: ViewStore<AppAction, AppState> // received — a plain let
    let router: AppRouter

    var body: some View {
        NavigationStack(path: viewStore.binding(.state(\.path).action(review: AppAction.setPath))) {
            HomeScreen(viewStore: viewStore)
                .navigationDestination(for: AppRoute.self) { router.view(for: $0) }
        }
        .fullScreenCover(isPresented: viewStore.binding(.state(\.onboarding).action(\.finishOnboarding))) {
            router.view(for: .onboarding) // the router supplies env — crux resolved
        }
    }
}
```

## Communication between features

A presented child talks back through the core `.on` bridge — `.on(.action(…), dispatch: .action(…), reduce: …)`: the child emits an action, the bridge routes it to the presenter (clearing the route, seeding state). It works identically for same-store and separate-store children — no direct coupling.

## Topics

- ``Relay/Scope``
- ``ScopeOf``
- ``StoreOptionalFocus``
- ``StoreCollectionFocus``
- <doc:NavigationEndToEnd>
- <doc:StoresAtAGlance>
- <doc:StoreProjection>
