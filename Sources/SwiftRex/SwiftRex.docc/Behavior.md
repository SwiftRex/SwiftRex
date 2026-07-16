# ``SwiftRex/Behavior``

The primary composition unit — a monoid of ``Consequence``s fusing a ``Reducer``, a ``Middleware``, and state-driven supervision into one liftable, composable value.

## Overview

A `Behavior<Action, State, Environment>` *is* `[Consequence]`. Three fluent builders describe a feature's concerns, each composing by `<>`:

- ``reduce(_:)`` — the **Reducer**: a pure `(Action, inout State) -> Void`. The ``Store`` *maintains* the state.
- ``produce(_:)`` — the **Effect Producer**: an action produces an ``Effect``. The ``Store`` *performs* it.
- ``supervise(_:)`` — the **Effect Supervisor**: the *state* keeps a ``Supervision`` of ``Channel``s alive. The ``Store`` *supervises* them. See <doc:StateDrivenEffects>.

```swift
let room = Behavior<RoomAction, RoomState, RoomEnv>
    .reduce { action, state in … }                 // what changes
    .produce { action, ctx in … }                    // what to do because of an action
    .supervise { state in … }                      // what to keep alive while the state holds
```

Each builder exists as a **static** factory (`Behavior.reduce { … }`) and as an **instance** method (`someBehavior.produce { … }`), so a fluent chain is exactly an `<>` fold. To share pre-work between a mutation and its effect, use the grouped ``react(_:)`` builder — it hands you the action and returns a whole ``Reaction``:

```swift
Behavior.react { action, _ in
    guard case .load(let id) = action else { return .doNothing }
    return .reduce  { $0.isLoading = true }
           .produce { ctx in ctx.environment.api.fetch(id).asEffect() }
}
```

You can also pair the reducer and middleware axes with `Behavior(reducer:middleware:)`; ``Reducer/asBehavior()`` and ``Middleware/asBehavior`` lift each half on its own (a `Middleware`'s own `supervise` axis carries through).

### The algebra — the free monoid `[Consequence]`

`Behavior` is a `Monoid` — literally the free monoid over its consequences: ``combine(_:_:)`` **concatenates** the lists, ``identity`` is `[]`. Composing runs both behaviors' reactions on the same pre-mutation state (mutations fold **sequentially**, effects merge in **parallel** — each ``Reaction`` is a product monoid) and **unions** their supervisions. It is a single flat pass, not a nested closure tree, and an all-no-op fold stays ``ReducerOutcome/unchanged`` so the ``Store`` skips the notification entirely. See <doc:Algebra>.

```swift
let app = Behavior.combine(counter.lifted, profile.lifted)   // or counter.lifted <> profile.lifted
```

### Scaling a feature up

``lift(_:)`` raises a feature from its local types to the app's global types in one shot: a ``Relay/Scope`` names all three axes through a leading-dot builder — `.action` re-indexes the action (a `Prism`/`\.case`), `.state` focuses the slice (a `WritableKeyPath`/`Lens`/`AffineTraversal`), `.environment` narrows the world.

```swift
let lifted = room.lift(.action(AppAction.prism.room).state(\.room).environment(\.roomEnv))
```

`liftOptional` is the 0-or-1 host: a *state-only* scope over an optional (or otherwise affine) slice, with the action and environment axes left absent. While the focus is `nil` the behavior is a **complete no-op** — never asked to mutate, produce, or supervise (stricter than a plain affine state lift); while present it runs on the **unwrapped** value. A key-path spelling is sugar for the same call:

```swift
dayBehavior.liftOptional(.state(\AppState.currentDay))   // currentDay: DayDetail.State?
dayBehavior.liftOptional(\AppState.currentDay)           // key-path sugar
```

``liftCollection(_:)`` routes an addressed global action to **one** element of a collection. The state lane locates it — by `Identifiable` id (`.state(\.rows)`), a custom key (`.state(\.rows, id: \.slug)`), position (`.state(indexed: \.rows)`), or dictionary key (`.state(dictionary: \.configs)`) — while the action lane carries an ``ElementAction``:

```swift
rowBehavior.liftCollection(
    .action(AppAction.prism.row).state(\.rows).environment(\.rowEnv)
)
```

``liftEach(_:)`` is the broadcast form: one global action reaches **every** present element, the action lane bridging a plain inbound prism into the per-element ``ElementAction``:

```swift
rowBehavior.liftEach(
    .action(broadcast: AppAction.prism.tickAll, into: AppAction.prism.row)
        .state(\.rows).environment(\.rowEnv)
)
```

Every lift carries **all three** axes — including `supervise`: a lifted feature's channels are re-embedded and (for collections) per-element stamped, so state-driven nav and per-row sockets just work. In all four the lifted unit sees the **unwrapped** local value, and each element's effect ids and supervision fan out per element automatically. See <doc:Lifting>.

### Routing actions — the `.on(…)` bridge

The ``on(_:reduce:)`` family composes declarative action-routing onto any behavior: *when this action arrives, dispatch that one* — optionally co-locating a state mutation (`reduce:`) or a state guard (`when:`). Every `.on` is sugar for `combine(self, routingBehavior)`. There are 28 overloads across four families:

```swift
let behavior = Behavior<AppAction, AppState, World>.identity
    // — Prism family —
    .on(AppAction.prism.didLoad, dispatch: AppAction.renderItems)
    .on(AppAction.prism.didTapBuy, dispatch: AppAction.checkout, when: { $0.isLoggedIn })
    .on(AppAction.prism.didLoad,
        dispatch: AppAction.renderItems,
        reduce: { items, state in state.items = items; state.isLoading = false })
    .on(AppAction.prism.searchQuery, AppAction.prism.updateSearch)   // prism pair, same payload
    .on(AppAction.prism.didTapLogout, dispatch: AppAction.auth(.logout))  // Void payload → fixed action
    // — KeyPath family: the `\.case` spelling of the same patterns —
    .on(\.didLoad, dispatch: AppAction.renderItems)
    .on(\.didTapLogout,
        dispatch: AppAction.auth(.logout),
        reduce: { state in state.isLoggingOut = true })
    // — Bool-predicate family —
    .on({ if case .reset = $0 { true } else { false } }, dispatch: .clearAll)
    .on({ if case .submit = $0 { true } else { false } },
        reduce: { $0.isSubmitting = true },
        dispatch: .doSubmit,
        when: { !$0.isSubmitting })
    // — Pure routing: (Action) -> Action? —
    .on { action in
        guard case .didSearch(let query) = action else { return nil }
        return .performSearch(query)
    }
```

State is **never copied** unless the action filter passes first. Variants without `reduce:` and without `when:` use `mutation: .identity` — no `inout` reference to state is ever taken, guaranteeing zero copy-on-write interaction. The bridge is also the tool for **decoupled cross-feature communication**: route one module's output action into another module's input without either module importing the other — see <doc:Modularisation>.

## Topics

### Building a Behavior

- ``reduce(_:)``
- ``produce(_:)``
- ``supervise(_:)``
- ``react(_:)``
- ``handle(_:)``

### Composing

- ``combine(_:_:)``
- ``mconcat(_:)``
- ``sconcat(_:_:)``

### Lifting to a Larger Scope

- ``lift(_:)``
- ``liftAction(_:)``
- ``liftState(_:)``
- ``liftEnvironment(_:)``
- ``liftCollection(action:embed:stateContainer:elements:)``
- ``liftEach(action:embed:each:stateContainer:)``

## See Also

- ``Reducer``
- ``Middleware``
- ``Consequence``
- ``Reaction``
- ``Supervision``
- ``ReducerOutcome``
- ``Store``
- <doc:StateDrivenEffects>
- <doc:Algebra>
