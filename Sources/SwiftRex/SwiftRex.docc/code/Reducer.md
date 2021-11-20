# ``SwiftRex/Reducer``

The ``MiddlewareProtocol`` pipeline can do two things: dispatch outgoing actions and handling incoming actions. But what they can NOT do is changing the app state. Middlewares have read-only access to the up-to-date state of our apps, but when mutations are required we use the ``MutableReduceFunction`` function:

```swift
(ActionType, inout StateType) -> Void
```

Which has the same semantics (but better performance) than old ``ReduceFunction``:

```swift
(ActionType, StateType) -> StateType
```

Given an action and the current state (as a mutable inout), it calculates the new state and changes it:

```
initial state is 42
action: increment
reducer: increment 42 => new state 43

current state is 43
action: decrement
reducer: decrement 43 => new state 42

current state is 42
action: half
reducer: half 42 => new state 21
```

The function is reducing all the actions in a cached state, and that happens incrementally for each new incoming action.

It's important to understand that reducer is a synchronous operations that calculates a new state without any kind of side-effect (including non-obvious ones as creating `Date()`, using DispatchQueue or `Locale.current`), so never add properties to the ``Reducer`` structs or call any external function. If you are tempted to do that, please create a middleware and dispatch actions with Dates or Locales from it. 

Reducers are also responsible for keeping the consistency of a state, so it's always good to do a final sanity check before changing the state, like for example check other dependant properties that must be changed together.

Once the reducer function executes, the store will update its single source-of-truth with the new calculated state, and propagate it to all its subscribers, that will react to the new state and update Views, for example.

This function is wrapped in a struct to overcome some Swift limitations, for example, allowing us to compose multiple reducers into one (monoid operation, where two or more reducers become a single one) or lifting reducers from local types to global types.

The ability to lift reducers allow us to write fine-grained "sub-reducer" that will handle only a subset of the state and/or action, place it in different frameworks and modules, and later plugged into a bigger state and action handler by providing a way to map state and actions between the global and local ones. For more information about that, please check <doc:Lifting>.

A possible implementation of a reducer would be:
```swift
let volumeReducer = Reducer<VolumeAction, VolumeState>.reduce { action, currentState in
    switch action {
    case .louder:
        currentState = VolumeState(
            isMute: false, // When increasing the volume, always unmute it.
            volume: min(100, currentState.volume + 5)
        )
    case .quieter:
        currentState = VolumeState(
            isMute: currentState.isMute,
            volume: max(0, currentState.volume - 5)
        )
    case .toggleMute:
        currentState = VolumeState(
            isMute: !currentState.isMute,
            volume: currentState.volume
        )
    }
}
```

Please notice from the example above the following good practices:
- No `DispatchQueue`, threading, operation queue, promises, reactive code in there.
- All you need to implement this function is provided by the arguments `action` and `currentState`, don't use any other variable coming from global scope, not even for reading purposes. If you need something else, it should either be in the state or come in the action payload.
- Do not start side-effects, requests, I/O, database calls.
- Avoid `default` when writing `switch`/`case` statements. That way the compiler will help you more.
- Make the action and the state generic parameters as much specialised as you can. If volume state is part of a bigger state, you should not be tempted to pass the whole big state into this reducer. Make it short, brief and specialised, this also helps preventing `default` case or having to re-assign properties that are never mutated by this reducer.

```
                                                                                                                    ┌────────┐                                     
                                                       IO closure                                                ┌─▶│ View 1 │                                     
                      ┌─────┐                          (don't run yet)                       ┌─────┐             │  └────────┘                                     
                      │     │ handle  ┌──────────┐  ┌───────────────────────────────────────▶│     │ send        │  ┌────────┐                                     
                      │     ├────────▶│Middleware│──┘                                        │     │────────────▶├─▶│ View 2 │                                     
                      │     │ Action  │ Pipeline │──┐  ┌─────┐ reduce ┌──────────┐           │     │ New state   │  └────────┘                                     
                      │     │         └──────────┘  └─▶│     │───────▶│ Reducer  │──────────▶│     │             │  ┌────────┐                                     
    ┌──────┐ dispatch │     │                          │Store│ Action │ Pipeline │ New state │     │             └─▶│ View 3 │                                     
    │Button│─────────▶│Store│                          │     │ +      └──────────┘           │Store│                └────────┘                                     
    └──────┘ Action   │     │                          └─────┘ State                         │     │                                   dispatch    ┌─────┐         
                      │     │                                                                │     │       ┌─────────────────────────┐ New Action  │     │         
                      │     │                                                                │     │─run──▶│       IO closure        ├────────────▶│Store│─ ─ ▶ ...
                      │     │                                                                │     │       │                         │             │     │         
                      │     │                                                                │     │       └─┬───────────────────────┘             └─────┘         
                      └─────┘                                                                └─────┘         │                     ▲                               
                                                                                                      request│ side-effects        │side-effects                   
                                                                                                             ▼                      response                       
                                                                                                        ┌ ─ ─ ─ ─ ─                │                               
                                                                                                          External │─ ─ async ─ ─ ─                                
                                                                                                        │  World                                                   
                                                                                                         ─ ─ ─ ─ ─ ┘                                               
```
