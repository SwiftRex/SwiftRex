# State-Driven Navigation

Model navigation as a function of state: routes live in state, SwiftUI bindings dispatch, and a router builds destination views — resolving the environment that an env-free view body can't.

## Overview

Navigation in SwiftRex is **pure SwiftUI Views reacting to state**. There is one store for the whole app; a view reads it through a view store (a `ViewStore`, granular per key path — see <doc:StoresAtAGlance>). Behavior mutates the navigation *state* (a route, an optional, a path, a selection); it never touches the view or the router. Every SwiftUI navigation container — sheet, cover, popover, alert, dialog, inspector, `NavigationStack`, `NavigationSplitView`, `TabView`, pages, windows — is just a pluggable *rendering* of one of four state **shapes**:

| Shape | State | Lift | Binding | Reducer |
| --- | --- | --- | --- | --- |
| **Optional / modal** — 0-or-1, child created on present | `Item?` | `liftOptional` | `binding(.state(\.x).action(\.close))` → `Binding<Item?>` / `Binding<Bool>` | ``Behavior/navigationItem(_:action:allow:)`` |
| **Stack** — 0-to-N ordered | `[Route]` | `liftCollection` | `binding(.state(\.x).action(\.setX))` | ``Behavior/navigationStack(_:action:allow:)`` |
| **Selection** — exactly 1-of-N, all alive | `Sel` (enum/id) | plain `lift` ×N | `binding(.state(\.x).action(\.setX))` | ``Behavior/navigationSelection(_:action:allow:)`` |
| **Scene set** — 0-to-N windows | keyed sub-states | element/dictionary projection | `hasScene(_:in:)` + `WindowGroup(for:)` | ordinary open/close actions |

The rest is: pick the shape, drive its binding, resolve the destination through a router. No new dialect — the bindings feed *native* SwiftUI modifiers. The bindings live on the **view store** (`ViewStore`) — on a plain `Store` they don't compile, because SwiftUI couldn't observe them.

> This page is the **reference** — each shape and container in isolation. For one app that wires all four shapes across every layer (domain → features → the global feature → behavior fold → scopes → router → views → `@main`), with the full stack shown, follow <doc:NavigationEndToEnd>.

## Every container, by shape

### Optional / modal — `Item?`

Presentation and child lifetime are one fact: set the optional and the child exists and shows; clear it and it tears down. Model the presentation as the **optional content** itself — never a `Bool` flag beside it: one value says both *whether* it shows and *what* it shows, so the two can't disagree. Then pick the binding the modifier wants: `item(_:dismiss:)` for `.sheet(item:)`-style modifiers (the content is `Identifiable`), `presence(_:dismiss:)` for `isPresented:`-style ones — a `Binding<Bool>` that is `true` while the optional is `.some` (pass the content through `presenting:` where the modifier takes it). Both only ever dispatch the *dismiss* action — presentation is driven by state, never by the binding.

```swift
// Every `\.slot` below is an OPTIONAL holding the content (`onboarding: Onboarding.State?`, `tip: Tip?`, …).
// Sheet, full-screen cover, popover — item- or isPresented-driven, interchangeably:
.sheet(item: store.binding(.state(\.editing).action(\.dismissEditor))) { item in router.view(for: .editor(item.id)) }
.fullScreenCover(isPresented: store.binding(.state(\.onboarding).action(\.finishOnboarding))) { router.view(for: .onboarding) }
.popover(item: store.binding(.state(\.tip).action(\.dismissTip))) { tip in TipView(tip) }

// Bottom sheet — a sheet whose content carries detents:
.sheet(isPresented: store.binding(.state(\.filters).action(\.closeFilters))) {
    router.view(for: .filters).presentationDetents([.medium, .large])
}

// Inspector (iOS 17+) — `isPresented:`-driven, over the optional inspected value:
.inspector(isPresented: store.binding(.state(\.inspector).action(\.hideInspector))) { router.view(for: .inspector) }

// Single push via NavigationStack, without a path:
.navigationDestination(isPresented: store.binding(.state(\.detail).action(\.popDetail))) { router.view(for: .detail) }

// Alert / confirmation dialog — present with a dismiss-only binding; the BUTTONS dispatch their own actions:
.alert("Delete?", isPresented: store.binding(.state(\.deleteConfirm).action(\.cancelDelete)), presenting: store.state.deleteConfirm.value) { item in
    Button("Delete", role: .destructive) { store.dispatch(.confirmDelete(item.id)) }
    Button("Cancel", role: .cancel) { store.dispatch(.cancelDelete) }
}
.confirmationDialog("Sort", isPresented: store.binding(.state(\.sortDialog).action(\.closeSort))) {
    Button("Newest") { store.dispatch(.sort(.newest)) }
    Button("Oldest") { store.dispatch(.sort(.oldest)) }
}
```

Behavior side: `liftOptional` (the child runs only while `.some`) or ``Behavior/navigationItem(_:action:allow:)`` for standard present/dismiss with an optional veto.

#### `Presentation` — model the dismissal frame instead of hacking it

`Item?` is *two* states (shown / gone), but a dismiss is *three*: shown, **animating-out-still-showing-the-last-value**, gone. Squeezing that middle state out is what forces the ugly `?? .placeholder` (content blanks as it slides away) or a view-layer latch. ``Presentation`` names it — `presented(x)` / `dismissing(last: x)` / `dismissed` — exactly as ``Loading`` names `reloading(previous:)`. It's a **pure** state type (core, no SwiftUI): the store stays the single source of truth, no latch, no timer.

```swift
struct State { var editor: Presentation<Editor.State> = .dismissed }          // slot
enum Action  { case editor(PresentationAction<Editor.Action>) }                // dismiss / child (present is a reducer)

// behavior — one lift folds present, the stage machine, and the child:
Editor.behavior().liftPresentation(action: \.editor, state: \.editor, environment: { $0.editorEnv })

// view — a Binding<Presentation> carries BOTH dismiss edges, so the state can't get stuck mid-dismiss:
content.sheet(item: store.binding(.state(\.editor).action(\.editor))) { _ in router.view(for: .editor) }
```

SwiftUI reports a dismissal twice, and so does ``PresentationAction``: `.dismiss` when it *starts* (the binding goes `false`/`nil` — `presented → dismissing`) and `.dismissed` when the animation *ends* (`onDismiss`, a real SwiftUI completion, not a timer). `binding(.state(\.editor).action(\.editor))` on a `Presentation` slot returns a `Binding<Presentation<T>>` that carries both: `.sheet(item:)` takes it directly for an `Identifiable` value; for any other container take its parts — `.fullScreenCover(isPresented: editor.isPresented(), onDismiss: editor.onDismiss())`, or `.item()` for an `item:` parameter. There is deliberately no `Bool` binding straight from a `Presentation` slot: without `onDismiss` the slot would stay `dismissing`. Content renders the value carried by *both* live stages, so it stays put through the animation. The plain `Item?` bindings above remain the *simple* path when the dismissal flicker doesn't matter.

#### Building the child view — `transpose()`

An optional-shaped destination is a store of an *optional* (`Child?`), but `Child.view(store:environment:)` wants a store of the *unwrapped* value. `transpose()` swaps the nesting — `Store<Child?>` becomes `Store<Child>?` — so the child store exists exactly when its state is present. On the view store, the caller depends only on that **presence edge**: it redraws when the child appears or disappears, never when something inside the child changes (the child observes its own state).

```swift
// Optional child slice — scope by key path, then transpose:
if let child = store.focus(.action(\.child).state(\.child)).transpose() {
    Detail.view(store: child, environment: world.detailEnv)
}

// A lane no key path expresses (an affine `preview`, the top of a stack, an enum case):
if let screen = store.transpose(action: { .detail($0) }, state: { $0.path.last?.detail }) {
    Detail.view(store: screen, environment: world.detailEnv)
}
```

For the ``Presentation`` shape, `transpose()` reads the live child through **both** `presented` and `dismissing(last:)`, going `nil` only once `dismissed` — the child store (and its view) stay alive and steady while SwiftUI animates the sheet out, so building a destination this way is flicker-free without any view-layer latch:

```swift
if let editor = store.focus(.action(\.editor.child).state(\.editor)).transpose() {   // state: Presentation<Editor.State>
    Editor.view(store: editor, environment: world.editorEnv)
}
```

A list iterates the collection with `each` — the list depends on the ids, each row on its own element — and focuses each row for its own store, through the same collection scope a projection takes:

```swift
List(store.state.each(\.rows)) { row in
    if let rowStore = store.focus(.action(\.row).state(\.rows), element: row.id).transpose() {
        Row.view(store: rowStore, environment: world.rowEnv)
    }
}
```

The row store reads through the list's view store (no new subscription), dispatches `RowAction` as `.row(ElementAction(id, action))`, finds its element in O(1) however the array moves, and holds its last value while it animates out. Nothing is asked of the state: a plain array of `Identifiable` values.

> Note: `transpose` reads the presence edge synchronously in a body, so it lives on `ViewStore`. Outside SwiftUI, presence is plain state — follow `stateStream.map { $0.child != nil }.removeDuplicates()` and present or dismiss on the edge. The forms above depend on the presence edge only, never on the child's contents.

### Stack — `[Route]`

`NavigationStack(path:)` reflects the whole path; SwiftUI hands the binding the new path on any change, so one `setPath` action covers push, back-swipe, and pop-to-root. Destinations resolve through the router.

```swift
NavigationStack(path: store.binding(.state(\.path).action(review: NavAction.setPath))) {
    RootView(...)
        .navigationDestination(for: AppRoute.self) { route in router.view(for: route) }
}
```

Behavior side: `liftCollection` per element, plus ``Behavior/navigationStack(_:action:allow:)`` for `push`/`pop`/`popToRoot`/`setPath` (veto e.g. a pop while a form is dirty).

### Selection — 1-of-N, all children alive

Tabs, split view, and paged/carousel views keep every child mounted; only the selection changes. All children are lifted **unconditionally** (siblings in state). Unlike modal dismiss, selecting is a normal state change, so `binding(_:dispatch:)` dispatches on every change.

```swift
// Tabs:
TabView(selection: store.binding(.state(\.tab).action(review: AppAction.selectTab))) {
    router.view(for: .home).tag(Tab.home)
    router.view(for: .search).tag(Tab.search)
}

// Paged / carousel — same selection, page style:
TabView(selection: store.binding(.state(\.page).action(review: AppAction.selectPage))) { … }
    .tabViewStyle(.page)

// Split view — selection + column visibility (the latter is just a plain `binding`):
NavigationSplitView(columnVisibility: store.binding(.state(\.columns).action(review: AppAction.setColumns))) {
    Sidebar(selection: store.binding(.state(\.selectedItem).action(review: AppAction.select)))   // optional selection
} detail: {
    router.view(for: .detail)
}
```

> A background/unselected child keeps running by default (that's the point of tabs). To pause one, add a supervisor keyed on the selection — it's your policy, not a framework default.

### Scene set — windows, one store

Multiple windows are still one store. Model open scenes as state (a dictionary of per-scene sub-states); each window projects its slice by id; open/close are ordinary actions; `hasScene(_:in:)` (on the view store) tells a window body whether to render or dismiss.

```swift
var body: some Scene {
    WindowGroup { RootView(store: store, router: router) }
    WindowGroup(for: DocID.self) { $id in
        if let id, store.hasScene(id, in: \.documents) {
            Document.view(
                store: store.projection(key: id, actionReview: AppAction.document, stateDictionary: \.documents),
                environment: world.docEnv
            )
        }
    }
    // `Settings`, `MenuBarExtra`, `Window` follow the same single-store pattern.
}
```

`openWindow(value: DocID(…))` / `dismissWindow` are triggered by dispatching actions that add or remove a scene's sub-state — the window set is a function of state.

### System & UIKit content — share sheet, pickers, web, Safari

Interruptive system UI and UIKit screens aren't a new shape — they're the **optional/modal** shape with a `UIViewControllerRepresentable`/`UIViewRepresentable` as the presented *content*. State drives *whether* it shows (`item`/`presence`, dismiss-only as always); the representable's `Coordinator` dispatches actions back for its results, so an outcome flows in as an ordinary action.

```swift
.sheet(item: store.binding(.state(\.sharing).action(\.doneSharing))) { payload in
    ActivityView(items: payload.items)              // UIViewControllerRepresentable(UIActivityViewController)
}
.sheet(isPresented: store.binding(.state(\.picker).action(\.cancelPicker))) {
    PhotoPicker { images in store.dispatch(.picked(images)) }   // Coordinator dispatches the result
}
.fullScreenCover(item: store.binding(.state(\.browsing).action(\.closeBrowser))) { page in
    WebView(url: page.url)                          // WKWebView / SwiftUI WebView, or SFSafariViewController
}
```

The rule is unchanged: presentation is a function of state (the binding only *dismisses*); UIKit *results* come back as actions via the representable's `Coordinator` → `store.dispatch`. A web view's own in-page back/forward is the web view's business — if you want it in state, that's just the web feature's `State`. `ShareLink` (a tap-to-share view with no presented state) needs none of this — use it directly.

## URLs — deep links in, external opens out

A URL is never a navigation *shape* by itself; it sits at one of two boundaries:

- **Incoming** (deep link / universal link) — an *action source*. Turn the URL into an action; the reducer sets navigation state; the app navigates like any other transition:
  ```swift
  RootView(store: store, router: router).onOpenURL { url in store.dispatch(.openedURL(url)) }
  // reducer: case .openedURL(let u): state.path = route(for: u)
  ```
- **Outgoing** (open an external URL — Safari, Mail, Maps) — a *side effect*, not navigation: your app backgrounds, nothing is presented. Inject an `openURL` dependency in `World` and produce a fire-and-forget effect (pure and testable), or call SwiftUI's `@Environment(\.openURL)` from a button for a trivial case:
  ```swift
  // World: let openURL: @Sendable (URL) -> Void
  case .tappedSupport: .produce { ctx in Effect.fireAndForget { ctx.environment.openURL(supportURL) } }
  ```

## Relay.Scope — declare the wiring once, drive both sides

A ``Relay/Scope`` captures how a child ``Feature`` embeds into the app store — action prism, state key path, environment narrowing — and drives **both** the child's lifted `.behavior(of:)` and its `.view(of:from:world:)`. Building one is a **compile-time proof** the feature is wired; a missing state slot, action case, or env mapping is a compile error at the literal.

```swift
// The wiring — declared once. `ScopeOf<AppFeature>` pins the app `Rig`'s triad, so every root infers.
let detail = ScopeOf<AppFeature>
    .action(\.detail).state(\.detail).environment(\.detailEnv)
detail.behavior(of: Detail.self)                       // Behavior<AppAction, AppState, World> — register it
detail.view(of: Detail.self, from: store, world: world) // Detail's view, env supplied — call from the router
```

Register every scope's behavior in one place — the behaviors are a monoid, so fold them with ``Behavior/combine(_:)-(Array)`` (or `<>`):

```swift
let appBehavior = Behavior.combine([
    home.behavior(of: Home.self),
    detail.behavior(of: Detail.self),
    Behavior.navigationStack(\.path, action: \.nav)   // + navigation reducers, logging, …
])
let store = Store(initial: .init(), behavior: appBehavior, environment: world)
```

A child feature's `Feature` conformance is generated by `@Feature` — no hand-written `extension Detail: Feature {}` — with Swift inferring the associated types from the members the macro generates.

## Router — the WHAT (and the environment crux)

`Feature.view(store:environment:)` needs an environment, but a navigation destination runs inside the *environment-free* view body. A **router** — a value holding the view store and the world — resolves that: its `@ViewBuilder view(for:)` switch builds each child (via `Relay.Scope`'s `.view(of:from:world:)` or directly), supplying the child's environment there. `some View` throughout — no `AnyView`.

```swift
@MainActor struct AppRouter {
    let store: ViewStore<AppAction, AppState>   // received from the owner (`@OwnedStore` at the root)
    let world: World
    let detail = ScopeOf<AppFeature>
        .action(\.detail).state(\.detail).environment(\.detailEnv)

    @ViewBuilder func view(for route: AppRoute) -> some View {
        switch route {
        case .detail: detail.view(of: Detail.self, from: store, world: world)   // env supplied here — crux resolved
        }
    }
}
```

A navigating view conforms to ``Routable`` and holds its router as a `let`, handed in at construction. Because the router builds every view, it re-hands itself at each construction — deterministic across the sheet/modal boundaries where SwiftUI's `@Environment` propagation is unreliable. The view body stays environment-free, and never names the child — the router does, so a route may resolve to a completely separate module (its own store slice and dependencies) without the presenting feature importing it.

```swift
struct HomeView: View, Routable {
    let viewStore: ViewStore<Home.Action, Home.State>
    let router: AppRouter
    var body: some View {
        List { … }.sheet(isPresented: viewStore.binding(.state(\.route).action(\.dismiss))) {
            router.view(for: .detail)   // router supplies env — crux resolved
        }
    }
}
```

## Communication between features

A presented child talks back through the core ``Behavior/on(_:dispatch:reduce:)`` bridge: the child emits an action, a bridge routes it to the presenter (clearing the route, seeding state). It works identically for same-store and separate-store children — no direct coupling.

## Topics

- ``Relay/Scope``
- ``Feature``
- ``Routable``
- ``Presentation``
- ``PresentationAction``
- <doc:StoresAtAGlance>
- <doc:StoreProjection>
