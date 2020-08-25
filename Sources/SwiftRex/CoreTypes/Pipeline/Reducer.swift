/**
 ⚙ `Reducer` is a pure function wrapped in a monoid container, that takes an action and the current state to calculate
 the new state.

 The `Middleware` pipeline will be notified about actions, or even trigger new ones, but what they can NOT do is
 changing the app state. Middlewares have read-only access to the up-to-date state of our apps, but when mutations are
 required we must use the `Reducer` function:

 ```
 (ActionType, StateType) -> StateType
 ```

 Given an action and the current state, returns the calculated state. This function will be executed in the last stage
 of an action handling, when all middlewares had the chance to read the action and start their own side-effects.

 It's important to understand that reducer is a synchronous operations that calculates a new state without any kind of
 side-effect, so never add properties to the `Reducer` structs or call any external function. If you are tempted to do
 that, please create a middleware. Reducers are also responsible for keeping the consistency of a state, so it's always
 good to do a final sanity check before changing the state, like for example check other dependant properties that must
 be changed together.

 Once the reducer function executes, the store will update its single source of truth with the new calculated state,
 and propagate it to all its observers, that will react to the new state and update Views, for example.

 This function is wrapped in a struct to overcome some Swift limitations, for example, allowing us to compose multiple
 reducers into one (monoid operation, where two or more reducers become a single one) or lifting reducers from local
 types to global types. The ability to lift reducers allow us to create small reducers, specialized in parts of our
 state only, written in different frameworks and modules, and later plugged into a bigger state and action handler by
 providing a way to map state and actions between the global and local ones. For more information about that, please
 check the functions `lift(actionGetter:stateGetter:stateSetter:)` and `lift(action:state:)`.

 A possible implementation of a reducer would be:
 ```
 let volumeReducer = Reducer<VolumeAction, VolumeState> = { action, currentState in
     switch action {
     case .louder:
         return VolumeState(
             isMute: currentState.isMute,
             volume: min(100, currentState.volume + 5)
         )
     case .quieter:
         return VolumeState(
             isMute: currentState.isMute,
             volume: max(0, currentState.volume - 5)
         )
     case .toggleMute:
         return VolumeState(
             isMute: !currentState.isMute,
             volume: currentState.volume
         )
     }
 }
 ```

 Please notice from the example above the following good practices:
 - No `DispatchQueue`, threading, operation queue, promises, reactive code in there
 - All you need to implement this function is provided by the arguments `action` and `currentState`, don't use any other
 variable coming from global scope, not even for reading purposes. If you need something else, it should be in the state
 - Do not start side-effects, requests, I/O, database calls
 - Avoid `default` when writing `switch`/`case` statements. That way the compiler will help you more
 - Make the action and the state generic parameters as much specialized as you can. If volume state is part of a bigger
 state, you should not be tempted to pass the whole big state into this reducer. Make it short, brief and specialized,
 this also helps preventing `default` case or having to re-assign properties that are never mutated by this reducer.
 ```
                   ┌─────┐                                                                                        ┌─────┐
                   │     │     handle   ┌──────────┐ request      ┌ ─ ─ ─ ─  response     ┌──────────┐ dispatch   │     │
                   │     │   ┌─────────▶│Middleware├─────────────▶ External│─────────────▶│Middleware│───────────▶│Store│─ ─ ▶ ...
                   │     │   │ Action   │ Pipeline │ side-effects │ World    side-effects │ callback │ New Action │     │
                   │     │   │          └──────────┘               ─ ─ ─ ─ ┘              └──────────┘            └─────┘
 ┌──────┐ dispatch │     │   │
 │Button│─────────▶│Store│──▶│                                                         ┌────────┐
 └──────┘ Action   │     │   │                                                      ┌─▶│ View 1 │
                   │     │   │                                  ┌─────┐             │  └────────┘
                   │     │   │ reduce   ┌──────────┐            │     │ onNext      │  ┌────────┐
                   │     │   └─────────▶│ Reducer  ├───────────▶│Store│────────────▶├─▶│ View 2 │
                   │     │     Action   │ Pipeline │ New state  │     │ New state   │  └────────┘
                   └─────┘     +        └──────────┘            └─────┘             │  ┌────────┐
                               State                                                └─▶│ View 3 │
                                                                                       └────────┘
 ```
 */
public struct Reducer<ActionType, StateType> {
    /**
     Execute the wrapped reduce function. You must provide the parameters `action: ActionType` (the action to be
     evaluated during the reducing process) and an `inout` version of the latest `state: StateType`, (the current
     state in your single source-of-truth).
     State will be mutated in place (`inout`) and finish with the calculated new state.
     */
    public let reduce: MutableReduceFunction<ActionType, StateType>

    /**
     Reducer initializer takes only the underlying function `(ActionType, StateType) -> StateType` that is the reducer
     function itself.
     - Parameters:
       - reduce: a pure function that is gonna be wrapped in a monoid container, and that calculates the new state from
                 an action and the old state.
     */
    public init(_ reduce: @escaping ReduceFunction<ActionType, StateType>) {
        self.init { action, state in
            state = reduce(action, state)
        }
    }

    /**
     Reducer initializer takes only the underlying function `(ActionType, inout StateType) -> Void` that is the reducer
     function itself.
     - Parameters:
       - reduce: a pure function that is gonna be wrapped in a monoid container, and that calculates the new state from
                 an action and the old state.
     */
    public static func reduce(_ reduce: @escaping MutableReduceFunction<ActionType, StateType>) -> Reducer {
        Reducer(reduce: reduce)
    }

    private init(reduce: @escaping MutableReduceFunction<ActionType, StateType>) {
        self.reduce = reduce
    }
}

extension Reducer: Monoid {
    /**
     Neutral monoidal container. Composing any monoid with an `identity` monoid should result in a function unchanged,
     regardless if the identity element is on the left-hand side or the right-hand side or this composition.

     Therefore:
     ```
        Reducer<ActionType, StateType> <> .identity
     == .identity <> Reducer<ActionType, StateType>
     == Reducer<ActionType, StateType>
     ```

     The implementation of this reducer, as one should expect, simply ignores the action and returns the state unchanged
     */
    public static var identity: Reducer<ActionType, StateType> {
        .init { _, _ in }
    }

    /**
     Monoid Append operation. Allows to compose two reducers into one, keeping in mind that the order of the composition
     DOES matter. When composing reducer A with reducer B, when an action X arrives, first it will be forwarded to
     reducer A together with the initial state. This reducer may return a slightly (or completely) changed state from
     that operation, and this state will then be forwarded to reducer B together with the same action X. If you change
     the order, results may vary as you can imagine. Monoids don't necessarily hold the commutative axiom, although
     sometimes they do. What they necessarily hold is the associativity axiom, which means that if you compose A and B,
     and later C, it's exactly the same as if you compose A to a previously composed B and C:
     `(A <> B) <> C == A <> (B <> C)`. So please don't worry about surrounding your reducers with parenthesis:
     ```
     let globalReducer = firstReducer <> secondReducer <> thirdReducer <> andSoOn
     ```

     - Parameters:
       - lhs: First monoid `(ActionType, StateType) -> StateType`, let's call it `f(x)`
       - rhs: Second monoid `(ActionType, StateType) -> StateType`, let's call it `g(x)`
     - Returns: a composed monoid `(ActionType, StateType) -> StateType` equivalent to `g(f(x))`
     */
    public static func <> (lhs: Reducer<ActionType, StateType>, rhs: Reducer<ActionType, StateType>) -> Reducer<ActionType, StateType> {
        .reduce { action, state in
            lhs.reduce(action, &state)
            rhs.reduce(action, &state)
        }
    }
}

extension Reducer {
    /**
     A type-lifting method. The global state of your app is _Whole_, and the `Reducer` handles _Part_, that is a
     sub-state.

     Let's suppose you may want to have a `gpsReducer` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it _Part_. Both, this state and its reducer will be part of an external framework, used by dozens of
     apps. Internally probably the `Reducer` will receive some known `ActionType` and calculate a new location. On the
     main app we have a global state, that we now call _Whole_.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, _Part_ (`Location`) is a property of _Whole_ (`MyGlobalState`). This relationship could be less
     direct, for example there could be several levels of properties until you find the _Part_ in the _Whole_, like
     `global.firstLevel.secondLevel.currentLocation`, but let's keep it a single-level for this example.

     Because our `Store` understands _Whole_ (`MyGlobalState`) and our `gpsReducer` understands _Part_ (`Location`), we
     must `lift` the `Reducer` to the _Whole_ level, by using:

     ```
     let globalStateReducer = gpsReducer.lift(actionGetter: { $0 },
                                              stateGetter: { global in return global.currentLocation },
                                              stateSetter: { global, part in global.currentLocation = path })
     ```

     Now this reducer can be used within our `Store` or even composed with others. It also can be used in other apps as
     long as we have a way to lift it to the world of _Whole_.

     Same strategy works for the `action`, as you can guess by the `actionGetter` parameter. You can provide a function
     that takes a global action (_Whole_) and returns an optional local action (_Part_). It's optional because perhaps
     you want to ignore actions that are not relevant for this reducer.

     - Parameters:
       - actionGetter: a way to convert a global action into a local action, but it's optional because maybe this
                       reducer shouldn't care about certain actions. Because actions are usually enums, you can switch
                       over the enum and in case it's nothing you care about, you simply return nil in the closure. If
                       you don't want to lift this reducer in terms of `action`, just provide the identity function
                       `{ $0 }` as input.
       - stateGetter: a way to read from a global state and extract only the part that it's relevant for this reducer,
                      by traversing the tree of the global state until you find the property you want, for example:
                      `{ $0.currentGame.scoreBoard }`
       - stateSetter: a way to write back into the global state once you finished reducing the _Part_, so now you have
                      a new part that was calculated by this reducer and you want to set it into the global state, also
                      provided as the first parameter as an `inout` property:
                      `{ globalState, newScoreBoard in globalState.currentGame.scoreBoard = newScoreBoard }`
     - Returns: a `Reducer<GlobalAction, GlobalState>` that maps actions and states from the original specialized
                reducer into a more generic and global reducer, to be used in a larger context.
     */
    public func lift<GlobalActionType, GlobalStateType>(
        actionGetter: @escaping (GlobalActionType) -> ActionType?,
        stateGetter: @escaping (GlobalStateType) -> StateType,
        stateSetter: @escaping (inout GlobalStateType, StateType) -> Void)
        -> Reducer<GlobalActionType, GlobalStateType> {
        .reduce { globalAction, globalState in
            guard let localAction = actionGetter(globalAction) else { return }
            var localState = stateGetter(globalState)
            self.reduce(localAction, &localState)
            stateSetter(&globalState, localState)
        }
    }

    /**
     A type-lifting method. The global state of your app is _Whole_, and the `Reducer` handles _Part_, that is a
     sub-state.

     Let's suppose you may want to have a `gpsReducer` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it _Part_. Both, this state and its reducer will be part of an external framework, used by dozens of
     apps. Internally probably the `Reducer` will receive some known `ActionType` and calculate a new location. On the
     main app we have a global state, that we now call _Whole_.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, _Part_ (`Location`) is a property of _Whole_ (`MyGlobalState`). This relationship could be less
     direct, for example there could be several levels of properties until you find the _Part_ in the _Whole_, like
     `global.firstLevel.secondLevel.currentLocation`, but let's keep it a single-level for this example.

     Because our `Store` understands _Whole_ (`MyGlobalState`) and our `gpsReducer` understands _Part_ (`Location`), we
     must `lift` the `Reducer` to the _Whole_ level, by using:

     ```
     let globalStateReducer = gpsReducer.lift(action: \.locationActions,
                                              state: \.currentLocation)
     ```

     Now this reducer can be used within our `Store` or even composed with others. It also can be used in other apps as
     long as we have a way to lift it to the world of _Whole_.

     Same strategy works for the `action`, as you can guess by the `action` parameter. You can provide a key-path that
     traverses from a global action (_Whole_) and to an optional local action (_Part_). It's optional because perhaps
     you want to ignore actions that are not relevant for this reducer.

     - Parameters:
       - action: a read-only key-path from global action into a local action, but it's optional because maybe this
                 reducer shouldn't care about certain actions. Because actions are usually enums, you can switch over
                 the enum and in case it's nothing you care about, you simply return nil in the closure. If you don't
                 want to lift this reducer in terms of `action`, just remove this parameter from the call.
       - state: a writable key-path from global state that traverses into a local state, by extracting only the part
                that it's relevant for this reducer. This will also be used to set the new local state into the global
                state once the reducer finishes it's operation. For example: `\.currentGame.scoreBoard`.
     - Returns: a `Reducer<GlobalAction, GlobalState>` that maps actions and states from the original specialized
                reducer into a more generic and global reducer, to be used in a larger context.
     */
    public func lift<GlobalActionType, GlobalStateType>(
        action: KeyPath<GlobalActionType, ActionType?>,
        state: WritableKeyPath<GlobalStateType, StateType>)
        -> Reducer<GlobalActionType, GlobalStateType> {
        .reduce { globalAction, globalState in
            guard let localAction = globalAction[keyPath: action] else { return }
            self.reduce(localAction, &globalState[keyPath: state])
        }
    }

    /**
     A type-lifting method. The global state of your app is _Whole_, and the `Reducer` handles _Part_, that is a
     sub-state.

     Let's suppose you may want to have a `gpsReducer` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it _Part_. Both, this state and its reducer will be part of an external framework, used by dozens of
     apps. Internally probably the `Reducer` will receive some known `ActionType` and calculate a new location. On the
     main app we have a global state, that we now call _Whole_.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, _Part_ (`Location`) is a property of _Whole_ (`MyGlobalState`). This relationship could be less
     direct, for example there could be several levels of properties until you find the _Part_ in the _Whole_, like
     `global.firstLevel.secondLevel.currentLocation`, but let's keep it a single-level for this example.

     Because our `Store` understands _Whole_ (`MyGlobalState`) and our `gpsReducer` understands _Part_ (`Location`), we
     must `lift` the `Reducer` to the _Whole_ level, by using:

     ```
     let globalStateReducer = gpsReducer.lift(state: \.currentLocation)
     ```

     Now this reducer can be used within our `Store` or even composed with others. It also can be used in other apps as
     long as we have a way to lift it to the world of _Whole_.

     Same strategy works for the `action`, just check the other available signatures for `lift` function.

     - Parameters:
       - state: a writable key-path from global state that traverses into a local state, by extracting only the part
                that it's relevant for this reducer. This will also be used to set the new local state into the global
                state once the reducer finishes it's operation. For example: `\.currentGame.scoreBoard`.
     - Returns: a `Reducer<ActionType, GlobalState>` that maps actions and states from the original specialized
                reducer into a more generic and global reducer, to be used in a larger context.
     */
    public func lift<GlobalStateType>(
        state: WritableKeyPath<GlobalStateType, StateType>
    ) -> Reducer<ActionType, GlobalStateType> {
        .reduce { action, globalState in
            self.reduce(action, &globalState[keyPath: state])
        }
    }

    /**
     A type-lifting method. The global state of your app is _Whole_, and the `Reducer` handles _Part_, that is a
     sub-state.

     Let's suppose you may want to have a `gpsReducer` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it _Part_. Both, this state and its reducer will be part of an external framework, used by dozens of
     apps. Internally probably the `Reducer` will receive some known `ActionType` and calculate a new location. On the
     main app we have a global state, that we now call _Whole_.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, _Part_ (`Location`) is a property of _Whole_ (`MyGlobalState`). This relationship could be less
     direct, for example there could be several levels of properties until you find the _Part_ in the _Whole_, like
     `global.firstLevel.secondLevel.currentLocation`, but let's keep it a single-level for this example.

     Because our `Store` understands _Whole_ (`MyGlobalState`) and our `gpsReducer` understands _Part_ (`Location`), we
     must `lift` the `Reducer` to the _Whole_ level, by using:

     ```
     let globalStateReducer = gpsReducer.lift(action: \.locationActions)
     ```

     Now this reducer can be used within our `Store` or even composed with others. It also can be used in other apps as
     long as we have a way to lift it to the world of _Whole_.

     Same strategy works for the `action`, as you can guess by the `action` parameter. You can provide a key-path that
     traverses from a global action (_Whole_) and to an optional local action (_Part_). It's optional because perhaps
     you want to ignore actions that are not relevant for this reducer.

     - Parameters:
       - action: a read-only key-path from global action into a local action, but it's optional because maybe this
                 reducer shouldn't care about certain actions. Because actions are usually enums, you can switch over
                 the enum and in case it's nothing you care about, you simply return nil in the closure. If you don't
                 want to lift this reducer in terms of `action`, just remove this parameter from the call.
     - Returns: a `Reducer<GlobalAction, StateType>` that maps actions and states from the original specialized
                reducer into a more generic and global reducer, to be used in a larger context.
     */
    public func lift<GlobalActionType>(
        action: KeyPath<GlobalActionType, ActionType?>)
        -> Reducer<GlobalActionType, StateType> {
        lift(action: action, state: \.self)
    }
}
