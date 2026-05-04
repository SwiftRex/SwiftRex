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
   - [CollectionAction — one-sided](#1-collectionaction--one-sided)
   - [Identifiable by `.id`](#2-identifiable-by-id)
   - [Custom Hashable identifier](#3-custom-hashable-identifier)
   - [Index-based](#4-index-based)
   - [Dictionary key](#5-dictionary-key)
   - [Primitive AffineTraversal](#6-primitive-affinetraversal)
5. [Putting it all together](#putting-it-all-together)

---

## Domain model used in this document

All examples share a single app model so the snippets read as a coherent whole.

```swift
// ── App-level ──────────────────────────────────────────────────────────────

enum AppAction {
    case auth(AuthAction)
    case profile(ProfileAction)
    case counter(CounterAction)
    case updateTodo(CollectionAction<AppState, Todo, TodoAction>)
    case updateProject((id: UUID, action: ProjectAction)?)
    case expandSection((index: Int, action: SectionAction)?)
    case updateConfig((key: String, action: ConfigAction)?)
}

struct AppState {
    var auth: AuthState
    var profile: ProfileState
    var counter: Int = 0
    var todos: [Todo] = []
    var projects: [Project] = []
    var sections: [Section] = []
    var configs: [String: Config] = [:]
}

// ── Auth ───────────────────────────────────────────────────────────────────

enum AuthAction {
    case login(String)
    case logout
    case tokenRefreshed(String)
}

struct AuthState {
    var token: String? = nil
    var isLoggingIn: Bool = false
}

// ── Profile ────────────────────────────────────────────────────────────────

enum ProfileAction {
    case updateName(String)
    case updateAvatar(URL)
}

struct ProfileState {
    var name: String = ""
    var avatarURL: URL? = nil
}

// ── Counter ────────────────────────────────────────────────────────────────

enum CounterAction { case increment; case decrement; case reset }

// ── Todos ──────────────────────────────────────────────────────────────────

enum TodoAction { case toggleDone; case updateTitle(String) }

struct Todo: Identifiable {
    let id: UUID
    var title: String
    var isDone: Bool = false
}

// ── Projects ───────────────────────────────────────────────────────────────

enum ProjectAction { case rename(String); case archive }

struct Project: Identifiable {
    let id: UUID
    var name: String
    var isArchived: Bool = false
}

// ── Sections ───────────────────────────────────────────────────────────────

enum SectionAction { case expand; case collapse }

struct Section {
    var title: String
    var isExpanded: Bool = false
}

// ── Configs ────────────────────────────────────────────────────────────────

enum ConfigAction { case toggle; case setValue(String) }

struct Config {
    var value: String
    var isEnabled: Bool = false
}
```

---

## Creating a Reducer

### `inout` form (preferred)

The internal representation is `(Action, inout State) -> Void`. Mutating `state` in place avoids copying large value trees on every action.

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
        state.isLoggingIn = true
    case .logout:
        state.token = nil
        state.isLoggingIn = false
    case .tokenRefreshed(let token):
        state.token = token
        state.isLoggingIn = false
    }
}
```

### Functional (pure-return) form

When the new state is naturally expressed as a transformation, the pure-return form can be cleaner. It bridges to `inout` internally so there is no semantic difference.

```swift
let profileReducer = Reducer<ProfileAction, ProfileState>.reduce { action, state in
    switch action {
    case .updateName(let name):
        ProfileState(name: name, avatarURL: state.avatarURL)
    case .updateAvatar(let url):
        ProfileState(name: state.name, avatarURL: url)
    }
}
```

The inout form is preferred for large state trees to avoid unnecessary copies.

---

## The Monoid: identity, combine, compose

`Reducer` is a **Monoid** under sequential composition. The two operations are:

| Operation | Meaning |
|-----------|---------|
| `Reducer.identity` | No-op; composing with it leaves any other reducer unchanged. |
| `combine(a, b)` / `compose` | Run `a` then `b` on the same `inout State`. `b` sees `a`'s mutations. |

### `identity`

```swift
let noOp = Reducer<AppAction, AppState>.identity
// noOp.reduce(action, &state) — state is always unchanged
```

Useful as a placeholder during development or as the result of a conditional composition.

### `combine`

Combines exactly two reducers. Order matters: the second reducer sees state after the first ran.

```swift
let combined = Reducer.combine(
    authReducer.lift(action: \AppAction.auth, state: \AppState.auth),
    profileReducer.lift(action: \AppAction.profile, state: \AppState.profile)
)
```

### `compose` — DSL form (recommended for three or more)

`Reducer.compose` takes a `@ReducerBuilder` block. Each line is an independent `Reducer` value; they are composed left-to-right via `combine`.

```swift
let appReducer = Reducer<AppAction, AppState>.compose {
    authReducer
        .lift(action: \AppAction.auth, state: \AppState.auth)

    profileReducer
        .lift(action: \AppAction.profile, state: \AppState.profile)

    counterReducer
        .lift(action: \AppAction.counter, state: \AppState.counter)
}
```

An empty `compose` block produces `identity`.

### `@ReducerBuilder` on your own functions

You can annotate any function, computed property, or parameter with `@ReducerBuilder` to get the DSL syntax without calling `compose` explicitly — just like `@ViewBuilder` in SwiftUI.

```swift
extension AppModule {
    @ReducerBuilder
    var reducer: Reducer<AppAction, AppState> {
        authReducer.lift(action: \AppAction.auth, state: \AppState.auth)
        profileReducer.lift(action: \AppAction.profile, state: \AppState.profile)
        counterReducer.lift(action: \AppAction.counter, state: \AppState.counter)
    }
}
```

### `compose` — variadic form

For two or more already-constructed reducers passed inline:

```swift
let appReducer = Reducer.compose(
    authReducer.lift(action: \AppAction.auth, state: \AppState.auth),
    profileReducer.lift(action: \AppAction.profile, state: \AppState.profile)
)
```

---

## Lifting to a larger scope

A reducer written against a local `(LocalAction, LocalState)` pair can be promoted to work on a broader `(GlobalAction, GlobalState)` pair via `lift`. The lifted reducer:

- **filters actions**: only runs when the global action maps to a local action (returns `nil` otherwise)
- **focuses state**: extracts the relevant slice before running, writes it back afterwards

Eleven overloads cover every combination of KeyPaths, closures, and optics.

### 1. KeyPath — action + state

The most common case. Works when `GlobalAction` has a stored optional property that is the local action, and `GlobalState` has a writable stored property that is the local state.

```swift
// AppAction must have: var auth: AuthAction?
// AppState must have:  var auth: AuthState

let liftedAuth = authReducer.lift(
    action: \AppAction.auth,   // KeyPath<AppAction, AuthAction?>
    state:  \AppState.auth     // WritableKeyPath<AppState, AuthState>
)
// Type: Reducer<AppAction, AppState>
```

```swift
let liftedCounter = counterReducer.lift(
    action: \AppAction.counter,
    state:  \AppState.counter
)
```

The reducer is skipped entirely when `globalAction[keyPath: action]` is `nil`.

### 2. KeyPath — state only

Use this when the action type is the same at both levels (no narrowing needed) and only the state needs to be focused.

```swift
// A sub-reducer that operates on Int, used where Int is a sub-field of AppState
let counterOnAppState: Reducer<CounterAction, AppState> =
    counterReducer.lift(state: \AppState.counter)
```

This is useful when you want to compose reducers at the same action level but different state slices, for example inside a `compose` block:

```swift
Reducer<AppAction, AppState>.compose {
    // All three handle AppAction but focus on different parts of AppState.
    // (Assumes each sub-reducer already accepts AppAction.)
    loggingReducer.lift(state: \AppState.log)
    metricsReducer.lift(state: \AppState.metrics)
    uiStateReducer.lift(state: \AppState.ui)
}
```

### 3. KeyPath — action only

Use when the state type is the same at both levels and only the action needs to be narrowed.

```swift
// AppAction has: var counter: CounterAction?
// Both operate on Int — state type is unchanged.

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
    actionGetter: { (global: AppAction) -> AuthAction? in
        if case .auth(let a) = global { return a } else { return nil }
    },
    stateGetter: { (global: AppState) in global.auth },
    stateSetter: { global, local in global.auth = local }
)
```

This is the right overload when:
- The property storing the local action or state is computed, not a `var` stored property
- The action projection requires pattern matching that isn't expressible as a single KeyPath
- You are composing optics that don't fit the `Prism`/`Lens` overloads below

### 5. Prism + Lens

When the action requires a `Prism` (e.g. a macro-generated enum prism) and the state requires a `Lens` (e.g. an immutable struct or a composed lens):

```swift
let authPrism = Prism<AppAction, AuthAction>(
    preview: { if case .auth(let a) = $0 { return a } else { return nil } },
    review:  { AppAction.auth($0) }
)

let authLens = Lens<AppState, AuthState>(
    get: { $0.auth },
    set: { appState, newAuth in AppState(auth: newAuth, profile: appState.profile, /* … */) }
)

let liftedAuth: Reducer<AppAction, AppState> =
    authReducer.lift(action: authPrism, state: authLens)
```

Use this when state is immutable (`let` properties) — `WritableKeyPath` is unavailable on `let` properties, but a `Lens` with an explicit `set` closure works for any struct.

**Composed lenses** are another common motivation. Two lenses can be composed into a single lens that focuses through two levels of nesting, and the result has no `WritableKeyPath` representation:

```swift
let appToAuth  = lens(\AppState.auth)            // Lens<AppState, AuthState>
let authToToken = lens(\AuthState.token)         // Lens<AuthState, String?>

// appToAuth.compose(authToToken) focuses AppState → String?
// No WritableKeyPath exists for this two-level path.
let deepLiftedReducer = tokenReducer.lift(
    action: tokenPrism,
    state:  appToAuth.compose(authToToken)
)
```

### 6. Prism — action only

Lifts only the action axis using a `Prism`. State type is unchanged. This is the idiomatic overload when your actions are generated by a `@Prism` macro:

```swift
// With a @Prism macro (future):
// let liftedAuth = authReducer.lift(action: AppAction.authPrism)

// Manual Prism construction:
let authPrism = Prism<AppAction, AuthAction>(
    preview: { if case .auth(let a) = $0 { return a } else { return nil } },
    review:  { .auth($0) }
)

let liftedAuth: Reducer<AppAction, AuthState> =
    authReducer.lift(action: authPrism)
```

### 7. Lens — state only

Lifts only the state axis using a `Lens`. Action type is unchanged. Prefer this over the `WritableKeyPath` variant when state properties are immutable or the focus spans multiple struct levels.

```swift
let authLens = Lens<AppState, AuthState>(
    get: { $0.auth },
    set: { AppState(auth: $1, profile: $0.profile, counter: $0.counter, /* … */) }
)

let liftedAuth: Reducer<AuthAction, AppState> =
    authReducer.lift(state: authLens)
```

### 8. Prism — partial (enum) state

When the **state itself is an enum** and the reducer only applies to one particular case, use a `Prism` on the state axis. The reducer is skipped when the state does not match the prism's focus; after running, the state is reconstructed via `review`.

```swift
enum SessionState {
    case loggedOut
    case loggingIn
    case loggedIn(AuthState)
}

let loggedInPrism = Prism<SessionState, AuthState>(
    preview: { if case .loggedIn(let s) = $0 { return s } else { return nil } },
    review:  { .loggedIn($0) }
)

// authReducer only runs when SessionState == .loggedIn(_).
let sessionReducer: Reducer<AuthAction, SessionState> =
    authReducer.lift(state: loggedInPrism)
```

### 9. Prism + Prism

When both the action and the state require a `Prism` — for example, the action is an enum case and the state is also an enum case. The reducer runs only when **both** prisms match.

```swift
let authPrism = Prism<AppAction, AuthAction>(
    preview: { if case .auth(let a) = $0 { return a } else { return nil } },
    review:  { .auth($0) }
)

let loggedInPrism = Prism<SessionState, AuthState>(
    preview: { if case .loggedIn(let s) = $0 { return s } else { return nil } },
    review:  { .loggedIn($0) }
)

let liftedReducer: Reducer<AppAction, SessionState> =
    authReducer.lift(action: authPrism, state: loggedInPrism)
```

### 10. AffineTraversal — state

An `AffineTraversal` is like a `Lens` but the focus may be absent (`preview` can return `nil`). This covers optional-valued state, out-of-bounds array slots, or any focus that is not guaranteed to exist. The reducer is skipped when `preview` returns `nil`.

```swift
// Focus on the first element of AppState.todos — may be nil if todos is empty.
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

Use `AffineTraversal` instead of `Lens` whenever the focused value might not exist.

### 11. Prism + AffineTraversal

Combines a `Prism` on the action axis with an `AffineTraversal` on the state axis. The reducer runs only when the action matches the prism **and** the traversal's `preview` finds a value.

```swift
let todoPrism = Prism<AppAction, TodoAction>(
    preview: { if case .updateTodo(let a) = $0 { return a.action } else { return nil } },
    review:  { _ in fatalError("review not used in this context") }
)

let firstTodoTraversal = AffineTraversal<AppState, Todo>(
    preview: { $0.todos.first },
    set: { s, t in var c = s; if !c.todos.isEmpty { c.todos[0] = t }; return c }
)

let liftedReducer: Reducer<AppAction, AppState> =
    todoReducer.lift(action: todoPrism, state: firstTodoTraversal)
```

---

## Lifting into collections

When an action targets a **specific element** inside a collection, `liftCollection` routes the action to the right element and writes the mutated element back in one step. Six strategies cover every element-selection technique.

All overloads have a `KeyPath` variant (ergonomic, when the action property is a stored property) and a `closure` variant (flexible, for any extraction logic).

### 1. CollectionAction — one-sided

`CollectionAction<Root, Element, SubAction>` bundles the element traversal **and** the local action into a single value that travels inside the global action. The call site pre-computes the routing; the reducer side just declares which action property carries the `CollectionAction`.

```swift
// ── Action side ────────────────────────────────────────────────────────────

// AppAction has:
//   case updateTodo(CollectionAction<AppState, Todo, TodoAction>)

// ── Dispatch site ──────────────────────────────────────────────────────────

store.send(.updateTodo(CollectionAction(\AppState.todos, id: todo.id, action: .toggleDone)))
store.send(.updateTodo(CollectionAction(\AppState.todos, id: todo.id, action: .updateTitle("Buy milk"))))

// ── Reducer side ───────────────────────────────────────────────────────────

let todoReducer = Reducer<TodoAction, Todo>.reduce { action, todo in
    switch action {
    case .toggleDone:           todo.isDone.toggle()
    case .updateTitle(let t):   todo.title = t
    }
}

// KeyPath variant — AppAction has: var updateTodo: CollectionAction<AppState, Todo, TodoAction>?
let liftedTodoReducer: Reducer<AppAction, AppState> =
    todoReducer.liftCollection(action: \AppAction.updateTodo)

// Closure variant — when extraction requires pattern matching
let liftedTodoReducer: Reducer<AppAction, AppState> =
    todoReducer.liftCollection(action: { (ga: AppAction) -> CollectionAction<AppState, Todo, TodoAction>? in
        if case .updateTodo(let ca) = ga { return ca } else { return nil }
    })
```

The `CollectionAction` initialiser family mirrors the strategies below. You can construct it with:

```swift
// By Identifiable.id
CollectionAction(\AppState.todos, id: todo.id, action: .toggleDone)

// By explicit ix traversal
CollectionAction(\AppState.todos, element: [Todo].ix(id: todo.id), action: .toggleDone)

// By index
CollectionAction(\AppState.sections, index: 2, action: .expand)

// By Dictionary key
CollectionAction(\AppState.configs, key: "featureX", action: .toggle)

// By custom AffineTraversal
CollectionAction(myCustomTraversal, action: .toggleDone)
```

The one-sided form is the most idiomatic SwiftRex pattern: the call site decides _which_ element to target, the reducer side stays completely unaware of where in the tree the element lives.

### 2. Identifiable by `.id`

When the element type conforms to `Identifiable`, the collection lookup happens by `id`. The action carries the element's id and the local action.

**Closure variant:**

```swift
// AppAction has no CollectionAction; it carries a raw id + sub-action tuple.
// (e.g. from a plain enum case with associated values)

let liftedTodo: Reducer<(id: UUID, action: TodoAction)?, AppState> =
    todoReducer.liftCollection(
        action: { (payload: (id: UUID, action: TodoAction)?) in payload },
        stateCollection: \AppState.todos
    )
```

**KeyPath variant** (requires a stored property on the action type):

```swift
struct AppAction {
    var updateTodo: (id: UUID, action: TodoAction)?
    // …
}

let liftedTodo: Reducer<AppAction, AppState> =
    todoReducer.liftCollection(
        action: \AppAction.updateTodo,
        stateCollection: \AppState.todos
    )
```

When the id is not found in the collection, the reducer is skipped without mutation.

### 3. Custom Hashable identifier

For elements that are `Identifiable` by some field that is not their `id` property, or for any type with a designated key field, use the `identifier:` parameter to name the key path.

**Closure variant:**

```swift
struct Project: Identifiable {
    let id: UUID
    var slug: String   // unique human-readable identifier
    var name: String
}

let projectReducer = Reducer<ProjectAction, Project>.reduce { action, project in
    switch action {
    case .rename(let n): project.name = n
    case .archive:       project.isArchived = true
    }
}

// Route by slug instead of by id
let liftedProject: Reducer<(id: String, action: ProjectAction)?, AppState> =
    projectReducer.liftCollection(
        action: { (p: (id: String, action: ProjectAction)?) in p },
        stateCollection: \AppState.projects,
        identifier: \Project.slug
    )
```

**KeyPath variant:**

```swift
struct AppAction {
    var updateProjectBySlug: (id: String, action: ProjectAction)?
}

let liftedProject: Reducer<AppAction, AppState> =
    projectReducer.liftCollection(
        action: \AppAction.updateProjectBySlug,
        stateCollection: \AppState.projects,
        identifier: \Project.slug
    )
```

### 4. Index-based

When the action carries the raw collection index. Use for arrays where stable position is meaningful, or when the UI dispatches by index (e.g. a table view row).

**Closure variant:**

```swift
let sectionReducer = Reducer<SectionAction, Section>.reduce { action, section in
    switch action {
    case .expand:   section.isExpanded = true
    case .collapse: section.isExpanded = false
    }
}

let liftedSection: Reducer<(index: Int, action: SectionAction)?, AppState> =
    sectionReducer.liftCollection(
        action: { (p: (index: Int, action: SectionAction)?) in p },
        stateCollection: \AppState.sections
    )
```

**KeyPath variant:**

```swift
// AppAction has: var expandSection: (index: Int, action: SectionAction)?

let liftedSection: Reducer<AppAction, AppState> =
    sectionReducer.liftCollection(
        action: \AppAction.expandSection,
        stateCollection: \AppState.sections
    )
```

Out-of-bounds indices produce no mutation.

### 5. Dictionary key

For `[Key: Value]` dictionaries. The action carries the key and the local action. Missing keys produce no mutation.

**Closure variant:**

```swift
let configReducer = Reducer<ConfigAction, Config>.reduce { action, config in
    switch action {
    case .toggle:         config.isEnabled.toggle()
    case .setValue(let v): config.value = v
    }
}

let liftedConfig: Reducer<(key: String, action: ConfigAction)?, AppState> =
    configReducer.liftCollection(
        action: { (p: (key: String, action: ConfigAction)?) in p },
        stateDictionary: \AppState.configs
    )
```

**KeyPath variant:**

```swift
// AppAction has: var updateConfig: (key: String, action: ConfigAction)?

let liftedConfig: Reducer<AppAction, AppState> =
    configReducer.liftCollection(
        action: \AppAction.updateConfig,
        stateDictionary: \AppState.configs
    )
```

### 6. Primitive AffineTraversal

The foundation all other `liftCollection` overloads are built on. Provide a closure that returns both the local action **and** an `AffineTraversal` that selects the exact element within its container. Use this when the built-in strategies don't fit — for example, a two-level nested collection, a custom container type, or a conditional traversal.

```swift
// Two levels deep: AppState.profile.recentTodos — a [Todo] nested inside ProfileState.
let nestedTodoReducer: Reducer<(id: UUID, action: TodoAction)?, AppState> =
    todoReducer.liftCollection(
        action: { (payload: (id: UUID, action: TodoAction)?) -> (action: TodoAction, element: AffineTraversal<[Todo], Todo>)? in
            payload.map { (action: $0.action, element: [Todo].ix(id: $0.id)) }
        },
        stateContainer: \AppState.profile.recentTodos
    )
```

```swift
// Custom container with a non-standard lookup — first incomplete todo.
let firstIncompleteTodoTraversal = AffineTraversal<[Todo], Todo>(
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
            (action: action, element: firstIncompleteTodoTraversal)
        },
        stateContainer: \AppState.todos
    )
```

---

## Putting it all together

A realistic app reducer that combines all of the above techniques:

```swift
// ── Leaf reducers ──────────────────────────────────────────────────────────

let authReducer = Reducer<AuthAction, AuthState>.reduce { action, state in
    switch action {
    case .login:                  state.isLoggingIn = true
    case .logout:                 state.token = nil; state.isLoggingIn = false
    case .tokenRefreshed(let t):  state.token = t; state.isLoggingIn = false
    }
}

let profileReducer = Reducer<ProfileAction, ProfileState>.reduce { action, state in
    switch action {
    case .updateName(let n):   state.name = n
    case .updateAvatar(let u): state.avatarURL = u
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

// ── App reducer ────────────────────────────────────────────────────────────
//
// AppAction is defined as:
//
//   enum AppAction {
//       case auth(AuthAction)
//       case profile(ProfileAction)
//       case counter(CounterAction)
//       case updateTodo(CollectionAction<AppState, Todo, TodoAction>)
//       case expandSection((index: Int, action: SectionAction)?)
//       case updateConfig((key: String, action: ConfigAction)?)
//   }
//
// AppAction computed properties used by KeyPath overloads:
//
//   extension AppAction {
//       var auth:          AuthAction?           { if case .auth(let a)    = self { return a } else { return nil } }
//       var profile:       ProfileAction?        { if case .profile(let a) = self { return a } else { return nil } }
//       var counter:       CounterAction?        { if case .counter(let a) = self { return a } else { return nil } }
//       var updateTodo:    CollectionAction<AppState, Todo, TodoAction>? {
//           if case .updateTodo(let ca) = self { return ca } else { return nil }
//       }
//       var expandSection: (index: Int, action: SectionAction)? {
//           if case .expandSection(let p) = self { return p } else { return nil }
//       }
//       var updateConfig:  (key: String, action: ConfigAction)? {
//           if case .updateConfig(let p) = self { return p } else { return nil }
//       }
//   }

let appReducer = Reducer<AppAction, AppState>.compose {
    // ── Struct state, enum action — KeyPath lift (most common) ──────────────
    authReducer
        .lift(action: \AppAction.auth, state: \AppState.auth)

    profileReducer
        .lift(action: \AppAction.profile, state: \AppState.profile)

    counterReducer
        .lift(action: \AppAction.counter, state: \AppState.counter)

    // ── Collection: one-sided CollectionAction ──────────────────────────────
    todoReducer
        .liftCollection(action: \AppAction.updateTodo)

    // ── Collection: index-based ─────────────────────────────────────────────
    sectionReducer
        .liftCollection(
            action: \AppAction.expandSection,
            stateCollection: \AppState.sections
        )

    // ── Collection: Dictionary key ──────────────────────────────────────────
    configReducer
        .liftCollection(
            action: \AppAction.updateConfig,
            stateDictionary: \AppState.configs
        )
}
```

### Quick reference — lift overload selection guide

```
Need to narrow the action?
├── Yes
│   ├── Action is a KeyPath optional property → lift(action:state:)  or  lift(action:)
│   ├── Action needs Prism (enum case, macro) → lift(action: prism, state: …)
│   └── Action needs custom logic → lift(actionGetter:stateGetter:stateSetter:)
└── No (same action type)
    └── lift(state: …)

Need to focus the state?
├── Stored var property → WritableKeyPath → lift(…state: keyPath)
├── Let property / composed path → Lens → lift(state: lens)
├── Enum case (state is an enum) → Prism → lift(state: prism)
└── Possibly-absent focus → AffineTraversal → lift(state: traversal)

Targeting an element inside a collection?
├── Carry all routing in the action → CollectionAction → liftCollection(action:)
├── Element is Identifiable → liftCollection(action:stateCollection:)
├── Element has a custom Hashable key → liftCollection(action:stateCollection:identifier:)
├── Target by index → liftCollection(action:stateCollection:)  (index variant)
├── Target by Dictionary key → liftCollection(action:stateDictionary:)
└── Custom traversal → liftCollection(action:stateContainer:)  (AffineTraversal primitive)
```

> **KeyPath vs closure vs optics** — Use the KeyPath overloads for the simplest cases (stored `var` properties). Reach for the `Lens`/`Prism`/`AffineTraversal` overloads when the focus is computed, immutable, composed across levels, or expressed as an enum case. Use the raw closure overload only when none of the optics overloads fit.
