/**
 ⚙ `Reducer` is a pure function wrapped in a monoid container, that takes current state and an action to calculate the new state.

 The `Middleware` pipeline can trigger `ActionProtocol`, and handles both `EventProtocol` and `ActionProtocol`. But what they can NOT do is changing the app state. Middlewares have read-only access to the up-to-date state of our apps, but when mutations are required we use the `Reducer` function. Actually, it's a protocol that requires only one method:

 ```
 func reduce(_ currentState: StateType, action: Action) -> StateType
 ```

 Given the current state and an action, returns the calculated state. This function will be executed in the last stage of an action handling, when all middlewares had the chance to modify or improve the action. Because a reduce function is composable monoid and also can be lifted through lenses, it's possible to write fine-grained "sub-reducer" that will handle only a "sub-state", creating a pipeline of reducers.

 It's important to understand that reducer is a synchronous operations that calculates a new state without any kind of side-effect, so never add properties to the `Reducer` structs or call any external function. If you are tempted to do that, please create a middleware. Reducers are also responsible for keeping the consistency of a state, so it's always good to do a final sanity check before changing the state.

 Once the reducer function executes, the store will update its single source of truth with the new calculated state, and propagate it to all its observers.
 */
public struct Reducer<StateType> {
    let reduce: (StateType, ActionProtocol) -> StateType

    /**
     Reducer initializer takes only the underlying function `(S, A) -> S` that is the reducer function itself.

     - Parameter reduce: a pure function that is gonna be wrapped in a monoid container, and that calculates the new state from the old state and an action.
     */
    public init(_ reduce: @escaping (StateType, ActionProtocol) -> StateType) {
        self.reduce = reduce
    }
}

extension Reducer: Monoid {
    /**
     Neutral monoidal container. Composing any monoid with an empty monoid should result in a function unchanged, regardless if the empty element is on the left-hand side or the right-hand side.

     Therefore, `Reducer<StateType> <> empty == Reducer<StateType> == empty <> Reducer<StateType>`
     */
    public static var empty: Reducer<StateType> {
        return Reducer { state, _ in state }
    }

    /**
     Monoid Append operation

     - Parameters:
       - lhs: First monoid `(S, A) -> S`, let's call it `f(x)`
       - rhs: Second monoid `(S, A) -> S`, let's call it `g(x)`
     - Returns: a composed monoid `(S, A) -> S` equivalent to `g(f(x))`
     */
    public static func <> (lhs: Reducer<StateType>, rhs: Reducer<StateType>) -> Reducer<StateType> {
        return Reducer { state, action in
            return rhs.reduce(lhs.reduce(state, action), action)
        }
    }
}

extension Reducer {
    /**
     A lenses method. The global state of your app is *Whole*, and the `Reducer` handles *Part*, that is a sub-state.
     So for example you may want to have a `gpsReducer` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it `Part`. Both, this state and its reducer will be part of an external framework, used by dozens of apps. Internally probably the `Reducer` will receive some known `ActionProtocol` and calculate a new location. On the main app we have a global state, that we now call `Whole`.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, `Part` is a property of `Whole`, maybe not directly, it could be several nodes deep in the tree.

     Because our `Store` understands `Whole` and our `gpsReducer` understands `Part`, we must `lift(_:)` the `Reducer` to the `Whole` level, by using:

     ```
     let globalStateReducer = gpsReducer.lift(\MyGlobalState.currentLocation)
     ```

     Now this reducer can be used within our `Store` or even composed with others. It also can be used in other apps as long as we have a way to lift it to the world of `Whole`.

     - Parameter substatePath: the keyPath that goes from `Whole` to `Part`
     - Returns: a `Reducer<Whole>` that maps `Whole` to `Part` and vice-versa, by using the key path.
     */
    public func lift<Whole>(_ substatePath: WritableKeyPath<Whole, StateType>) -> Reducer<Whole> {
        return Reducer<Whole> { wholeState, action in
            var wholeState = wholeState
            let substate = wholeState[keyPath: substatePath]
            wholeState[keyPath: substatePath] = self.reduce(substate, action)
            return wholeState
        }
    }
}
