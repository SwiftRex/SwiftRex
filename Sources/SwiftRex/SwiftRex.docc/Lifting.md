# Lifting Features

Write each feature against its own small types, then lift it up to the app's global types before composing.

## Overview

The point of SwiftRex's composition is that a feature never needs to know about the whole app. You write a ``Reducer``, ``Middleware``, or ``Behavior`` against a *local* `(Action, State, Environment)` — types that describe only that feature — and **lift** it to the app's *global* types right before you combine it with everything else. Lifting:

- **narrows the action** — the lifted unit runs only when the global action maps to the local one (otherwise it's skipped);
- **focuses the state** — it reads the relevant slice, runs, and writes the slice back;
- **narrows the environment** (``Middleware``/``Behavior`` only) — it projects the app's dependencies down to what the feature needs.

The lift API is the **same shape on `Reducer`, `Behavior`, and `Middleware`** — learn it once. After lifting, every feature is at the global types, so they compose with `combine` / the `@ReducerBuilder` DSL. See <doc:Algebra> for why that composition is lawful.

## The three axes

```swift
// counterReducer:  Reducer<CounterAction, Int>
// lifted:          Reducer<AppAction, AppState>
let lifted = counterReducer.lift(
    action: \AppAction.counter,   // narrow the action
    state:  \AppState.counter     // focus the state
)
```

`Behavior` and `Middleware` add a third axis, the environment:

```swift
let lifted = searchBehavior.lift(
    action:      \AppAction.search,
    state:       \AppState.search,
    environment: \AppEnvironment.searchAPI
)
```

Lift one axis at a time — `lift(action:)` / `lift(state:)` on ``Reducer``; `liftAction`, `liftState`, and `liftEnvironment` on ``Behavior`` and ``Middleware`` — or all of them together with `lift(action:state:…)`.

## Choosing the right optic per axis

Which kind of key path or optic you pass depends on the *shape* of your global type. SwiftRex accepts plain `KeyPath`s and the FP optics interchangeably.

### Action — narrow

- **`KeyPath<GlobalAction, LocalAction?>`** — a `@Prisms`-generated `\AppAction.counter`. The unit is skipped when it's `nil`.
- **`Prism<GlobalAction, LocalAction>`** — `AppAction.prism.counter`, the same thing in optic form (composes with `>>>`).

### State — focus

- **`WritableKeyPath<GlobalState, LocalState>`** — `\AppState.counter`, when the slice is a `var` stored property.
- **`Lens<GlobalState, LocalState>`** — `AppState.lens.counter` (`@Lenses`), when the slice is a `let` / immutable property; lenses compose through nested immutables with `>>>`.
- **`Prism<GlobalState, CaseState>`** — when the *state itself is an enum* and the feature applies to one case (`SessionState.prism.loggedIn`); the unit runs only in that case.
- **`AffineTraversal<GlobalState, LocalState>`** — when the focus may be **absent** (`preview` returns `nil`); the unit is skipped when there's nothing to focus.

### Environment — narrow

A projection (`\AppEnvironment.searchAPI` or a closure) maps the app's dependencies to the feature's. Library modules that don't know the app's environment commonly export a `(Dependencies) -> Behavior<…>` factory and let the app inject.

## Lifting into collections

A per-element feature runs across a whole collection of state, addressed by identity rather than position:

- **``Reducer/liftCollection(action:stateContainer:)``** and its overloads — for an `Identifiable` collection, a custom-keyed collection, or a `[Key: Value]` dictionary. Each element's action is wrapped in an ``ElementAction`` carrying the element's id.
- **``Reducer/liftEach(action:each:stateContainer:)``** — the broadcast form: apply the unit to *every* element.

```swift
// One TodoReducer drives every row; actions are addressed by todo id.
let todos = todoReducer.liftCollection(
    action: \AppAction.todo,            // KeyPath<AppAction, ElementAction<Todo.ID, TodoAction>?>
    stateCollection: \AppState.todos
)

// At the call site:
store.dispatch(.todo(ElementAction(todo.id, action: .toggleDone)))
```

Per-element effect scheduling is tagged per element, so one row's `.debounce(id:)` never collides with another's. See ``ElementAction``.

## Putting it together

Lifting is what lets independently-built feature modules meet at the Store:

```swift
let app = Behavior.combine(
    authBehavior.lift(action: \.auth,     state: \.auth,     environment: \.auth),
    searchBehavior.lift(action: \.search, state: \.search,   environment: \.searchAPI),
    todoReducer.liftCollection(action: \.todo, stateCollection: \.todos).asBehavior()
)
let store = Store(initial: .init(), behavior: app, environment: appEnv)
```

## See Also

- ``Reducer``
- ``Behavior``
- ``Middleware``
- ``ElementAction``
- <doc:Algebra>
