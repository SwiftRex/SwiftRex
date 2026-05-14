# Reducer

A `Reducer<ActionType, StateType>` is a pure function that maps an action and the current state to a new state. It is the **only** place in SwiftRex that mutates state — no side effects, no async work, no environment access. Those belong in `Middleware`.

---

## Contents

1. [Creating a Reducer](#creating-a-reducer)
2. [The Monoid: identity, combine, compose](#the-monoid-identity-combine-compose)
3. [Lifting to a larger scope](#lifting-to-a-larger-scope)
   - [KeyPath — action + state](#1-keypath--action--state)
   - [KeyPath — state only](#2-keypath--state-only)
   - [KeyPath — action only](#3-keypath--action-only)
   - [Closures — fully custom projection](#4-closures--fully-custom-projection)
   - [Prism + Lens](#5-prism--lens)
   - [Prism — action only](#6-prism--action-only)
   - [Lens — state only](#7-lens--state-only)
   - [Prism — partial (enum) state](#8-prism--partial-enum-state)
   - [Prism + Prism](#9-prism--prism)
   - [AffineTraversal — state](#10-affinetraversal--state)
   - [Prism + AffineTraversal](#11-prism--affinetraversal)
4. [Lifting into collections](#lifting-into-collections)
   - [Identifiable by `.id`](#1-identifiable-by-id)
   - [Custom Hashable identifier](#2-custom-hashable-identifier)
   - [Dictionary key](#3-dictionary-key)
   - [Index-based (primitive)](#4-index-based-primitive)
   - [Custom AffineTraversal](#5-custom-affinetraversal)
5. [Putting it all together](#putting-it-all-together)

---

## Domain model used in this document

All examples share a single app model. The `@Prisms` and `@Lenses` macros from the FP library are used throughout — they eliminate boilerplate optic construction while keeping types explicit.

```swift
import FPMacros

// ── App-level ──────────────────────────────────────────────────────────────

// @Prisms generates:
//   • AppAction.prism.auth      → Prism<AppAction, AuthAction>
//   • AppAction.prism.updateTodo → Prism<AppAction, ElementAction<UUID, TodoAction>>
//   • appAction.auth            → AuthAction?   (usable as KeyPath)
//   • appAction.updateTodo      → ElementAction<UUID, TodoAction>?  (usable as KeyPath)
//   … and so on for every case.
@Prisms
enum AppAction {
    case auth(AuthAction)
    case profile(ProfileAction)
    case counter(CounterAction)
    case updateTodo(ElementAction<UUID, TodoAction>)
    case updateProject(ElementAction<String, ProjectAction>)  // keyed by Project.slug
    case expandSection(ElementAction<Int, SectionAction>)
    case updateConfig(ElementAction<String, ConfigAction>)
}

// @Lenses(init: .public) generates:
//   • A public memberwise initialiser
//   • AppState.lens.auth     → Lens<AppState, AuthState>    (reconstruction, because let)
//   • AppState.lens.todos    → Lens<AppState, [Todo]>       (WritableKeyPath-based, because var)
//   … etc.
//
// let properties use a reconstruction lens (no WritableKeyPath exists on immutable fields).
// var properties use a WritableKeyPath-based lens and can also be addressed via \AppState.prop.
@Lenses(init: .public)
struct AppState {
    let auth: AuthState           // immutable — reconstruction lens
    let profile: ProfileState     // immutable — reconstruction lens
    let counter: Int              // immutable — reconstruction lens
    var todos: [Todo]             // mutable   — WritableKeyPath lens
    var sections: [Section]       // mutable   — WritableKeyPath lens
    var configs: [String: Config] // mutable   — WritableKeyPath lens
}

// ── Auth ───────────────────────────────────────────────────────────────────

@Prisms
enum AuthAction {
    case login(String)
    case logout
    case tokenRefreshed(String)
}

@Lenses(init: .public)
struct AuthState {
    let token: String?
    let isLoggingIn: Bool
}

// ── Profile ────────────────────────────────────────────────────────────────

@Prisms
enum ProfileAction {
    case updateName(String)
    case updateAvatar(URL)
}

@Lenses(init: .public)
struct ProfileState {
    let name: String
    let avatarURL: URL?
}

// ── Counter ────────────────────────────────────────────────────────────────

@Prisms
enum CounterAction { case increment; case decrement; case reset }

// ── Todos ──────────────────────────────────────────────────────────────────

@Prisms
enum TodoAction { case toggleDone; case updateTitle(String) }

struct Todo: Identifiable {
    let id: UUID
    var title: String
    var isDone: Bool = false
}

// ── Projects ───────────────────────────────────────────────────────────────

@Prisms
enum ProjectAction { case rename(String); case archive }

struct Project: Identifiable {
    let id: UUID
    var slug: String
    var name: String
    var isArchived: Bool = false
}

// ── Sections ───────────────────────────────────────────────────────────────

@Prisms
enum SectionAction { case expand; case collapse }

struct Section {
    var title: String
    var isExpanded: Bool = false
}

// ── Configs ────────────────────────────────────────────────────────────────

@Prisms
enum ConfigAction { case toggle; case setValue(String) }

struct Config {
    var value: String
    var isEnabled: Bool = false
}
```

---

## Creating a Reducer

`Reducer` stores `(ActionType) -> EndoMut<StateType>` internally: given an action it produces an
in-place endomorphism on `State`. The `Store` calls `reducer.reduce(action).runEndoMut(&_state)` in
its dispatch pipeline. All four constructor overloads bridge into that representation.

### `inout` form (idiomatic Swift)

Mutating `state` directly avoids copying large value trees. All CoW containers (`Array`, `Dictionary`,
`Set`) are updated in place because `inout` passes the exclusive reference — reference count stays 1.

```swift
let counterReducer = Reducer<CounterAction, Int>.reduce { action, state in
    switch action {
    case .increment: state += 1
    case .decrement: state -= 1
    case .reset:     state = 0
    }
}
```

```swift
let authReducer = Reducer<AuthAction, AuthState>.reduce { action, state in
    switch action {
    case .login:
        // Only isLoggingIn changes — lens copies the rest automatically.
        state = AuthState.lens.isLoggingIn.set(state, true)
    case .logout:
        // All fields are known values — init is fine here.
        state = AuthState(token: nil, isLoggingIn: false)
    case .tokenRefreshed(let token):
        // Two fields change — chain: inner lens runs first, outer sees its result.
        state = AuthState.lens.isLoggingIn.set(AuthState.lens.token.set(state, token), false)
    }
}
```

`Lens.set(oldValue, newValue)` reconstructs the struct changing only the focused field. Every other
field is preserved automatically — no manual copying required.

### Functional (pure-return) form

When the new state is naturally expressed as a transformation the pure-return form reads more clearly.
It bridges to `EndoMut` via `Endo.toEndoMut()` internally — one copy per dispatch, acceptable for
small immutable structs:

```swift
let profileReducer = Reducer<ProfileAction, ProfileState>.reduce { action, state in
    switch action {
    case .updateName(let n):   ProfileState.lens.name.set(state, n)
    case .updateAvatar(let u): ProfileState.lens.avatarURL.set(state, u)
    }
}
```

Each case names only what changes. `@Lenses` handles the reconstruction of every untouched field.

Prefer the `inout` form for large mutable state trees; prefer the pure-return form for small
immutable structs.

### `(Action) -> Endo<State>` form

Use this when the reducer is naturally expressed as a function from action to a pure endomorphism.
Bridges via `.toEndoMut()` — one copy per dispatch.

```swift
let counterReducer = Reducer<CounterAction, Int>.reduce { action in
    switch action {
    case .increment: Endo { $0 + 1 }
    case .decrement: Endo { $0 - 1 }
    case .reset:     Endo { _ in 0 }
    }
}
```

### `(Action) -> EndoMut<State>` form (primary)

This is the form that maps 1:1 to the internal representation. Zero bridging overhead. Use when
composing `EndoMut` values directly or when optimising a hot path:

```swift
let counterReducer = Reducer<CounterAction, Int>.reduce { action in
    switch action {
    case .increment: EndoMut { $0 += 1 }
    case .decrement: EndoMut { $0 -= 1 }
    case .reset:     EndoMut { $0 = 0  }
    }
}
```

---

## The Monoid: identity, combine, compose

`Reducer` is a **Monoid** under sequential composition, and that Monoid is a direct **pointwise lift
of `EndoMut`'s Monoid**: for any action, `Reducer.combine(a, b).reduce(action)` is exactly
`EndoMut.combine(a.reduce(action), b.reduce(action))`.

| Operation | Meaning |
|-----------|---------|
| `Reducer.identity` | Returns `EndoMut.identity` for every action — the do-nothing closure. |
| `combine(a, b)` / `compose` | Combines the `EndoMut` values of `a` and `b` for each action; `b` sees `a`'s mutations. |

### `identity`

```swift
let noOp = Reducer<AppAction, AppState>.identity
// noOp.reduce(action)(&state) — state is always unchanged
```

Useful as a placeholder during development or as the result of a conditional composition.

### `combine`

Combines exactly two reducers. Order matters: the second reducer sees state after the first ran.

```swift
let combined = Reducer.combine(
    authReducer.lift(action: AppAction.prism.auth, state: AppState.lens.auth),
    profileReducer.lift(action: AppAction.prism.profile, state: AppState.lens.profile)
)
```

### `compose` — DSL form (recommended)

`Reducer.compose` takes a `@ReducerBuilder` block. Each line is an independent `Reducer` value; they are composed left-to-right via `combine`.

```swift
let appReducer = Reducer<AppAction, AppState>.compose {
    authReducer
        .lift(action: AppAction.prism.auth, state: AppState.lens.auth)

    profileReducer
        .lift(action: AppAction.prism.profile, state: AppState.lens.profile)

    counterReducer
        .lift(action: AppAction.prism.counter, state: AppState.lens.counter)
}
```

An empty `compose` block produces `identity`.

### `@ReducerBuilder` on your own functions

You can annotate any function, computed property, or parameter with `@ReducerBuilder` to get the DSL syntax without calling `compose` explicitly — just like `@ViewBuilder` in SwiftUI.

```swift
extension AppModule {
    @ReducerBuilder
    var reducer: Reducer<AppAction, AppState> {
        authReducer.lift(action: AppAction.prism.auth, state: AppState.lens.auth)
        profileReducer.lift(action: AppAction.prism.profile, state: AppState.lens.profile)
        counterReducer.lift(action: AppAction.prism.counter, state: AppState.lens.counter)
    }
}
```

### `compose` — variadic form

For two or more already-constructed reducers passed inline:

```swift
let appReducer = Reducer.compose(
    authReducer.lift(action: AppAction.prism.auth, state: AppState.lens.auth),
    profileReducer.lift(action: AppAction.prism.profile, state: AppState.lens.profile)
)
```

---

## Lifting to a larger scope

A reducer written against a local `(LocalAction, LocalState)` pair can be promoted to work on a broader `(GlobalAction, GlobalState)` pair via `lift`. The lifted reducer:

- **filters actions**: only runs when the global action maps to a local action (returns `nil` otherwise)
- **focuses state**: extracts the relevant slice before running, writes it back afterwards

Eleven overloads cover every combination of KeyPaths, closures, and optics.

### 1. KeyPath — action + state

Works when `GlobalAction` has a stored optional property (or a `@Prisms`-generated computed property) that is the local action, and `GlobalState` has a writable stored property that is the local state.

```swift
// @Prisms on AppAction generates \AppAction.auth → KeyPath<AppAction, AuthAction?>
// AppState.auth is a var, so \AppState.auth → WritableKeyPath<AppState, AuthState>

let liftedAuth = authReducer.lift(
    action: \AppAction.auth,   // KeyPath<AppAction, AuthAction?>
    state:  \AppState.auth     // WritableKeyPath<AppState, AuthState>
)
// Type: Reducer<AppAction, AppState>
```

The reducer is skipped entirely when `globalAction[keyPath: action]` is `nil`.

> When `AppState.auth` is a `let` property, `\AppState.auth` is not a `WritableKeyPath`.
> Use the [Prism + Lens](#5-prism--lens) overload instead.

### 2. KeyPath — state only

Use when the action type is the same at both levels and only the state needs to be focused.

```swift
let counterOnAppState: Reducer<CounterAction, AppState> =
    counterReducer.lift(state: \AppState.counter)
```

This is useful when composing reducers at the same action level but different state slices:

```swift
Reducer<AppAction, AppState>.compose {
    loggingReducer.lift(state: \AppState.log)
    metricsReducer.lift(state: \AppState.metrics)
    uiStateReducer.lift(state: \AppState.ui)
}
```

> For `let` properties use `lift(state: MyState.lens.prop)` — see [Lens — state only](#7-lens--state-only).

### 3. KeyPath — action only

Use when the state type is the same at both levels and only the action needs to be narrowed.

```swift
// @Prisms generates \AppAction.counter → KeyPath<AppAction, CounterAction?>
let liftedAction: Reducer<AppAction, Int> =
    counterReducer.lift(action: \AppAction.counter)
```

### 4. Closures — fully custom projection

The most flexible overload. Provide three closures explicitly:

- `actionGetter`: maps the global action to an optional local action (`nil` = skip)
- `stateGetter`: extracts local state from global state
- `stateSetter`: writes the mutated local state back into global state (via `inout`)

```swift
let liftedAuth = authReducer.lift(
    actionGetter: { (global: AppAction) in global.auth },   // @Prisms generated property
    stateGetter:  { (global: AppState) in global.auth },
    stateSetter:  { global, local in global = AppState(auth: local, profile: global.profile, /* … */) }
)
```

Use this when the projection requires logic that can't be expressed with KeyPaths or the optic overloads.

### 5. Prism + Lens

The primary overload for **immutable state**. `@Prisms` generates the action prism; `@Lenses` generates the state lens. Both are available as static properties on the respective types.

```swift
// AppAction.prism.auth  → Prism<AppAction, AuthAction>   (generated by @Prisms)
// AppState.lens.auth    → Lens<AppState, AuthState>      (reconstruction lens, generated by @Lenses)

let liftedAuth: Reducer<AppAction, AppState> =
    authReducer.lift(action: AppAction.prism.auth, state: AppState.lens.auth)
```

**Composed lenses** — `@Lenses`-generated lenses compose with `>>>` (from `CoreFPOperators`), letting you focus through multiple levels of immutable nesting:

```swift
// Focus AppState → AuthState → token: String?
// Neither step has a WritableKeyPath (both are let fields).
let tokenLens: Lens<AppState, String?> = AppState.lens.auth >>> AuthState.lens.token

let tokenReducer: Reducer<String?, AppState> =
    someTokenReducer.lift(state: tokenLens)
```

### 6. Prism — action only

Lifts only the action axis. State type is unchanged. `@Prisms` makes this a one-liner:

```swift
let liftedAuth: Reducer<AppAction, AuthState> =
    authReducer.lift(action: AppAction.prism.auth)
```

### 7. Lens — state only

Lifts only the state axis. Action type is unchanged. Use `@Lenses`-generated lenses for immutable (`let`) properties:

```swift
// AppState.lens.auth is a reconstruction lens — @Lenses handles the full-struct rebuild.
let liftedAuth: Reducer<AuthAction, AppState> =
    authReducer.lift(state: AppState.lens.auth)
```

Compare with the `WritableKeyPath` variant for `var` properties:

```swift
// AppState.todos is a var — both forms are equivalent.
let liftedTodosA = someReducer.lift(state: \AppState.todos)
let liftedTodosB = someReducer.lift(state: AppState.lens.todos)
```

### 8. Prism — partial (enum) state

When the **state itself is an enum** and the reducer only applies to one particular case. `@Prisms` on the state enum generates the prism directly:

```swift
@Prisms
enum SessionState {
    case loggedOut
    case loggingIn
    case loggedIn(AuthState)
}

// authReducer only runs when SessionState == .loggedIn(_).
// Afterwards, SessionState.prism.loggedIn.review(mutatedAuth) reconstructs the full state.
let sessionReducer: Reducer<AuthAction, SessionState> =
    authReducer.lift(state: SessionState.prism.loggedIn)
```

### 9. Prism + Prism

When both the action and the state are enums. Both `@Prisms` macros compose naturally:

```swift
@Prisms
enum SessionState {
    case loggedOut
    case loggingIn
    case loggedIn(AuthState)
}

// Runs only when action is .auth(_) AND state is .loggedIn(_).
let liftedReducer: Reducer<AppAction, SessionState> =
    authReducer.lift(action: AppAction.prism.auth, state: SessionState.prism.loggedIn)
```

### 10. AffineTraversal — state

An `AffineTraversal` is like a `Lens` but the focus may be absent (`preview` can return `nil`). The reducer is skipped when `preview` returns `nil`. No macro generates these — build them directly:

```swift
// Focus on the first Todo — may be nil if todos is empty.
let firstTodoTraversal = AffineTraversal<AppState, Todo>(
    preview: { $0.todos.first },
    set: { appState, todo in
        var copy = appState
        if !copy.todos.isEmpty { copy.todos[0] = todo }
        return copy
    }
)

let liftedTodoReducer: Reducer<TodoAction, AppState> =
    todoReducer.lift(state: firstTodoTraversal)
```

### 11. Prism + AffineTraversal

Combines `@Prisms` on the action axis with an `AffineTraversal` on the state axis. Runs only when both match:

```swift
// Runs only when action is .updateTodo(_) AND todos is non-empty.
let liftedReducer: Reducer<AppAction, AppState> =
    todoReducer.lift(
        action: AppAction.prism.updateTodo,
        state: AffineTraversal<AppState, Todo>(
            preview: { $0.todos.first },
            set: { s, t in var c = s; if !c.todos.isEmpty { c.todos[0] = t }; return c }
        )
    )
```

---

## Lifting into collections

When an action targets a **specific element** inside a collection, `liftCollection` routes the action to the right element and writes the mutated element back in one step.

The core design principle: **the call site only knows what it uniquely knows** — the element's identifier and the action to send. The path to the collection inside global state belongs at the reducer wiring layer, not in the view. `ElementAction<ID, SubAction>` is the type that carries exactly that pair.

```swift
// View — only knows the id and the action:
store.send(.updateTodo(ElementAction(todo.id, action: .toggleDone)))

// Reducer wiring — knows where todos live in AppState:
todoReducer.liftCollection(action: \AppAction.updateTodo, stateCollection: \AppState.todos)
```

`@Prisms` on `AppAction` generates `\AppAction.updateTodo` as a `KeyPath<AppAction, ElementAction<UUID, TodoAction>?>`, which is exactly what the `liftCollection(action:stateCollection:)` KeyPath overload expects.

All overloads come in two flavours: a **KeyPath variant** (for `@Prisms`-generated or stored optional properties) and a **closure variant** (for pattern matching or any custom extraction).

### 1. Identifiable by `.id`

When the element type conforms to `Identifiable`. `liftCollection` looks up the element by `id`, runs the reducer, and writes back.

**KeyPath variant** — uses the `\AppAction.caseName` KeyPath generated by `@Prisms`:

```swift
// @Prisms generates \AppAction.updateTodo → KeyPath<AppAction, ElementAction<UUID, TodoAction>?>

// View:
store.send(.updateTodo(ElementAction(todo.id, action: .toggleDone)))
store.send(.updateTodo(ElementAction(todo.id, action: .updateTitle("Buy milk"))))

// Wiring:
let liftedTodo: Reducer<AppAction, AppState> =
    todoReducer.liftCollection(
        action: \AppAction.updateTodo,
        stateCollection: \AppState.todos
    )
```

**Closure variant** — uses the `@Prisms`-generated computed property for cleaner pattern extraction:

```swift
let liftedTodo: Reducer<AppAction, AppState> =
    todoReducer.liftCollection(
        action: { $0.updateTodo },   // @Prisms generated: appAction.updateTodo → ElementAction?
        stateCollection: \AppState.todos
    )
```

When the `id` is not found in the collection, the reducer is skipped without mutation.

### 2. Custom Hashable identifier

When the element is looked up by a field other than its `Identifiable.id`. Supply `identifier:` to name which property on the element to match against.

**KeyPath variant:**

```swift
// Project is looked up by its slug, not its UUID id.
// @Prisms generates \AppAction.updateProject → KeyPath<AppAction, ElementAction<String, ProjectAction>?>

let liftedProject: Reducer<AppAction, AppState> =
    projectReducer.liftCollection(
        action: \AppAction.updateProject,
        stateCollection: \AppState.projects,
        identifier: \Project.slug
    )
```

**Closure variant:**

```swift
let liftedProject: Reducer<AppAction, AppState> =
    projectReducer.liftCollection(
        action: { $0.updateProject },  // @Prisms generated
        stateCollection: \AppState.projects,
        identifier: \Project.slug
    )
```

### 3. Dictionary key

For `[Key: Value]` dictionaries. The `ElementAction.id` is the dictionary key. Missing keys produce no mutation.

**KeyPath variant:**

```swift
// View:
store.send(.updateConfig(ElementAction("featureX", action: .toggle)))

// Wiring:
let liftedConfig: Reducer<AppAction, AppState> =
    configReducer.liftCollection(
        action: \AppAction.updateConfig,
        stateDictionary: \AppState.configs
    )
```

**Closure variant:**

```swift
let liftedConfig: Reducer<AppAction, AppState> =
    configReducer.liftCollection(
        action: { $0.updateConfig },   // @Prisms generated
        stateDictionary: \AppState.configs
    )
```

### 4. Index-based (primitive)

Array indices are positional, not semantic identifiers, so there is no dedicated `ElementAction` overload for them. Use the primitive `AffineTraversal` overload, building the traversal with `[C].ix(_:)`. The `@Prisms`-generated computed property keeps the extraction clean:

```swift
// View (index comes from e.g. a table view row):
store.send(.expandSection(ElementAction(indexPath.row, action: .expand)))

// Wiring — $0.expandSection uses the @Prisms generated property:
let liftedSection: Reducer<AppAction, AppState> =
    sectionReducer.liftCollection(
        action: { (ga: AppAction) -> (action: SectionAction, element: AffineTraversal<[Section], Section>)? in
            guard let ea = ga.expandSection else { return nil }
            return (action: ea.action, element: [Section].ix(ea.id))
        },
        stateContainer: \AppState.sections
    )
```

Out-of-bounds indices produce no mutation.

### 5. Custom AffineTraversal

The primitive all other overloads delegate to. Use when the built-in strategies don't fit: two-level nested collections, custom container types, or conditional lookups.

```swift
// First incomplete todo — not addressable by a stable id or position.
let firstIncompleteTodo = AffineTraversal<[Todo], Todo>(
    preview: { $0.first(where: { !$0.isDone }) },
    set: { todos, updated in
        var copy = todos
        if let idx = copy.firstIndex(where: { !$0.isDone }) { copy[idx] = updated }
        return copy
    }
)

let liftedReducer: Reducer<TodoAction, AppState> =
    todoReducer.liftCollection(
        action: { (action: TodoAction) -> (action: TodoAction, element: AffineTraversal<[Todo], Todo>)? in
            (action: action, element: firstIncompleteTodo)
        },
        stateContainer: \AppState.todos
    )
```

```swift
// Two levels deep: AppState.profile.recentTodos via @Prisms + ix.
let nestedTodoReducer: Reducer<AppAction, AppState> =
    todoReducer.liftCollection(
        action: { (ga: AppAction) -> (action: TodoAction, element: AffineTraversal<[Todo], Todo>)? in
            guard let ea = ga.updateTodo else { return nil }
            return (action: ea.action, element: [Todo].ix(id: ea.id))
        },
        stateContainer: \AppState.profile.recentTodos
    )
```

---

## Putting it all together

A realistic app reducer using `@Prisms` and `@Lenses` throughout, with immutable state and the `compose` DSL:

```swift
import FPMacros

// ── Actions — @Prisms generates per-case prisms and computed optional properties ──

@Prisms enum AppAction {
    case auth(AuthAction)
    case profile(ProfileAction)
    case counter(CounterAction)
    case updateTodo(ElementAction<UUID, TodoAction>)
    case expandSection(ElementAction<Int, SectionAction>)
    case updateConfig(ElementAction<String, ConfigAction>)
}

// ── State — @Lenses generates a public memberwise init and per-field lenses ────
//
// let fields  → reconstruction Lens (no WritableKeyPath; @Lenses handles full-struct rebuild)
// var fields  → WritableKeyPath-based Lens (also addressable via \AppState.prop)

@Lenses(init: .public)
struct AppState {
    let auth: AuthState           // AppState.lens.auth    → Lens<AppState, AuthState>
    let profile: ProfileState     // AppState.lens.profile → Lens<AppState, ProfileState>
    let counter: Int              // AppState.lens.counter → Lens<AppState, Int>
    var todos: [Todo]             // \AppState.todos or AppState.lens.todos
    var sections: [Section]       // \AppState.sections or AppState.lens.sections
    var configs: [String: Config] // \AppState.configs or AppState.lens.configs
}

@Lenses(init: .public)
struct AuthState {
    let token: String?
    let isLoggingIn: Bool
}

@Lenses(init: .public)
struct ProfileState {
    let name: String
    let avatarURL: URL?
}

// ── Leaf reducers ──────────────────────────────────────────────────────────

let authReducer = Reducer<AuthAction, AuthState>.reduce { action, state in
    switch action {
    case .login:
        AuthState.lens.isLoggingIn.set(state, true)
    case .logout:
        AuthState(token: nil, isLoggingIn: false)
    case .tokenRefreshed(let token):
        AuthState.lens.isLoggingIn.set(AuthState.lens.token.set(state, token), false)
    }
}

let profileReducer = Reducer<ProfileAction, ProfileState>.reduce { action, state in
    switch action {
    case .updateName(let n):   ProfileState.lens.name.set(state, n)
    case .updateAvatar(let u): ProfileState.lens.avatarURL.set(state, u)
    }
}

let counterReducer = Reducer<CounterAction, Int>.reduce { action, state in
    switch action {
    case .increment: state += 1
    case .decrement: state -= 1
    case .reset:     state = 0
    }
}

let todoReducer = Reducer<TodoAction, Todo>.reduce { action, todo in
    switch action {
    case .toggleDone:           todo.isDone.toggle()
    case .updateTitle(let t):   todo.title = t
    }
}

let sectionReducer = Reducer<SectionAction, Section>.reduce { action, section in
    switch action {
    case .expand:   section.isExpanded = true
    case .collapse: section.isExpanded = false
    }
}

let configReducer = Reducer<ConfigAction, Config>.reduce { action, config in
    switch action {
    case .toggle:            config.isEnabled.toggle()
    case .setValue(let v):   config.value = v
    }
}

// ── App reducer — DSL compose with @Prisms + @Lenses ──────────────────────

let appReducer = Reducer<AppAction, AppState>.compose {
    // Immutable scalar state — Prism on action, Lens on state (reconstruction)
    authReducer
        .lift(action: AppAction.prism.auth, state: AppState.lens.auth)

    profileReducer
        .lift(action: AppAction.prism.profile, state: AppState.lens.profile)

    counterReducer
        .lift(action: AppAction.prism.counter, state: AppState.lens.counter)

    // Collection — Identifiable by UUID; \AppAction.updateTodo from @Prisms
    todoReducer
        .liftCollection(action: \AppAction.updateTodo, stateCollection: \AppState.todos)

    // Collection — index-based via primitive; ga.expandSection from @Prisms
    sectionReducer
        .liftCollection(
            action: { (ga: AppAction) -> (action: SectionAction, element: AffineTraversal<[Section], Section>)? in
                guard let ea = ga.expandSection else { return nil }
                return (action: ea.action, element: [Section].ix(ea.id))
            },
            stateContainer: \AppState.sections
        )

    // Collection — Dictionary key; \AppAction.updateConfig from @Prisms
    configReducer
        .liftCollection(action: \AppAction.updateConfig, stateDictionary: \AppState.configs)
}
```

### What the macros buy you

| Without macros | With macros |
|---|---|
| `Prism<AppAction, AuthAction>(preview: { … }, review: { … })` | `AppAction.prism.auth` |
| `Lens<AppState, AuthState>(get: { … }, set: { … })` | `AppState.lens.auth` |
| `{ if case .auth(let a) = $0 { return a } else { return nil } }` | `{ $0.auth }` or `\AppAction.auth` |
| Handwritten memberwise init for immutable structs | `@Lenses(init: .public)` generates it |
| Composed lens built manually | `AppState.lens.auth >>> AuthState.lens.token` |

### Dispatch examples (view layer)

```swift
// View knows only the element's id and the action — nothing about AppState layout:
store.send(.updateTodo(ElementAction(todo.id, action: .toggleDone)))
store.send(.updateTodo(ElementAction(todo.id, action: .updateTitle("Buy milk"))))

store.send(.expandSection(ElementAction(indexPath.row, action: .expand)))

store.send(.updateConfig(ElementAction("featureX", action: .toggle)))
store.send(.updateConfig(ElementAction("debugMode", action: .setValue("verbose"))))
```

### Quick reference — lift overload selection guide

```
Need to narrow the action?
├── Yes
│   ├── Stored/computed optional property → lift(action: \AppAction.case, state: …)
│   ├── @Prisms on AppAction             → lift(action: AppAction.prism.case, state: …)
│   └── Custom logic                     → lift(actionGetter:stateGetter:stateSetter:)
└── No (same action type)
    └── lift(state: …)

Need to focus the state?
├── var stored property   → WritableKeyPath → lift(state: \AppState.prop)
├── let stored property   → @Lenses Lens   → lift(state: AppState.lens.prop)
├── Composed path         → Lens >>>        → lift(state: AppState.lens.a >>> AState.lens.b)
├── Enum case             → @Prisms Prism  → lift(state: MyState.prism.case)
└── Possibly-absent focus → AffineTraversal → lift(state: myTraversal)

Targeting an element inside a collection?
├── Element is Identifiable   → ElementAction<ID, A>  + liftCollection(action: \AppAction.case, stateCollection: \AppState.prop)
├── Custom Hashable field     → ElementAction<Key, A> + liftCollection(action:stateCollection:identifier:)
├── Dictionary entry          → ElementAction<Key, A> + liftCollection(action:stateDictionary:)
├── Array index               → ElementAction<Int, A> + liftCollection(action:stateContainer:)  ← primitive
└── Conditional / nested      → AffineTraversal       + liftCollection(action:stateContainer:)  ← primitive
```

> `@Prisms` on any enum makes `.prism.caseName` (static `Prism`) and `.caseName` (computed optional property, usable as `KeyPath`) available instantly.
> `@Lenses(init:)` on any struct makes `.lens.propName` available for both `let` and `var` properties, and generates the memberwise init.
