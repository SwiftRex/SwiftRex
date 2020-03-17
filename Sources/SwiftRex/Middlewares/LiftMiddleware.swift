/**
 This is a container that lifts a sub-state middleware to a global state middleware.

 Internally you find the middleware responsible for handling events and actions for a sub-state (`Part`), while this outer class will be able to compose with global state (`Whole`) in your `Store`.

 You should not be able to instantiate this class directly, instead, create a middleware for the sub-state and call `Middleware.lift(_:)`, passing as parameter the keyPath from whole to part.
 */
public struct LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, PartMiddleware: Middleware>: Middleware {
    public typealias InputActionType = GlobalInputActionType
    public typealias OutputActionType = GlobalOutputActionType
    public typealias StateType = GlobalStateType
    typealias LocalInputActionType = PartMiddleware.InputActionType
    typealias LocalOutputActionType = PartMiddleware.OutputActionType
    typealias LocalStateType = PartMiddleware.StateType

    private let partMiddleware: PartMiddleware
    private let inputActionMap: (GlobalInputActionType) -> LocalInputActionType?
    private let outputActionMap: (LocalOutputActionType) -> GlobalOutputActionType
    private let stateMap: (GlobalStateType) -> LocalStateType

    public init(middleware: PartMiddleware,
                inputActionMap: @escaping (GlobalInputActionType) -> PartMiddleware.InputActionType?,
                outputActionMap: @escaping (PartMiddleware.OutputActionType) -> GlobalOutputActionType,
                stateMap: @escaping (GlobalStateType) -> PartMiddleware.StateType) {
        self.inputActionMap = inputActionMap
        self.outputActionMap = outputActionMap
        self.stateMap = stateMap
        self.partMiddleware = middleware
    }

    public func receiveContext(getState: @escaping () -> GlobalStateType, output: AnyActionHandler<GlobalOutputActionType>) {
        partMiddleware.receiveContext(
            getState: { self.stateMap(getState()) },
            output: output.contramap(outputActionMap)
        )
    }

    /**
     Handles the incoming actions and may or not start async tasks, check the latest state at any point or dispatch
     additional actions. This is also a good place for analytics, tracking, logging and telemetry. Because the lift
     middleware is derived from a sub-state/sub-action middleware, every global action received will be mapped into
     a sub-action, in a operation that can return nil (`Optional<SubAction>`). In case it's nil, it means that the
     sub-action middleware doesn't work with this type of action, so the lifted middleware will simply call the next
     middleware in the chain. On the other hand, if this operation returns a non-nil local action, this local action will
     be handled by the child middleware, which is also responsible for calling `next()` in this case. When the `State`
     type is also lifted, the context property will translate the global state into local state as expected every time
     you call `context().getState()`.
     - Parameters:
       - action: the action to be handled
       - next: opportunity to call the next middleware in the chain and, eventually, the reducer pipeline. Call it
               only once, not more or less than once. Call it from the same thread and runloop where the handle function
               is executed, never from a completion handler or dispatch queue block. In case you don't need to compare
               state before and after it's changed from the reducers, please consider to add a `defer` block with `next()`
               on it, at the beginning of `handle` function.
     */
    public func handle(action: GlobalInputActionType, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        guard let localAction: LocalInputActionType = inputActionMap(action) else {
            // This middleware doesn't care about this action type
            return
        }

        return partMiddleware.handle(action: localAction, from: dispatcher, afterReducer: &afterReducer)
    }
}

extension Middleware {
    /**
     A method used to transform a middleware focused in a specific substate into a middleware that can be plugged in a global scope and composed with
     other middlewares that work on different generic parameters. The global state of your app is *Whole*, and the `Middleware` handles *Part*, that
     is a sub-state.
     So for example you may want to have a `GPSMiddleware` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it `Part`. Both, this state and its middleware will be part of an external framework, used by dozens of apps. Internally probably the
     `Middleware` will use `CoreLocation` to fetch the GPS changes, and triggers some actions. On the main app we have a global state, that we now
     call `Whole`.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, `Part` is a property of `Whole`, maybe not directly, it could be several nodes deep in the tree.

     Because our `Store` understands `Whole` and our `GPSMiddleware` understands `Part`, we must `lift(_:)` the middleware to the `Whole` level, by
     using:

     ```
     let globalStateMiddleware = gpsMiddleware.lift(stateMap: \MyGlobalState.currentLocation)
     ```

     Now this middleware can be used within our `Store` or even composed with others. It also can be used in other apps as long as we have a way to
     lift it to the world of `Whole`.

     - Parameters:
       - inputActionMap: a function that will be executed every time a global action arrives at the global store. Then you can optionally return an
                         action of type Middleware's local input action type so the middleware will handle this action, or you can return nil in case
                         you want this middleware to ignore this global action. This is useful because not all middlewares will care about all global
                         actions. Usually this is a KeyPath in an enum, such as `\GlobalAction.someSubAction?.middlewareLocalAction` when you use code
                         generators to create enum properties.
       - outputActionMap: a function that will translate the local actions dispatched by this middleware into a global action type for your store.
                          Usually this is wrapping the enum in a global action tree, such as
                          `{ GlobalAction.someSubAction(.middlewareLocalAction($0)) }`.
       - stateMap: a function that will translate the global state of your store into the local state of this middleware. Usually this is a KeyPath in
                   the global state struct, such as `\GlobalState.subState.middlewareLocalState`.
     - Returns: a `LiftMiddleware` that knows how to translate `Whole` to `Part` and vice-versa. To the external world this resulting middleware will
                "speak" global types to be plugged into the main Store. Internally it will "speak" the types of the wrapped middleware.
     */
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, Self> {
        .init(
            middleware: self,
            inputActionMap: inputActionMap,
            outputActionMap: outputActionMap,
            stateMap: stateMap
        )
    }

    /**
     A method used to transform a middleware focused in a specific substate into a middleware that can be plugged in a global scope and composed with
     other middlewares that work on different generic parameters. The global state of your app is *Whole*, and the `Middleware` handles *Part*, that
     is a sub-state.
     So for example you may want to have a `GPSMiddleware` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it `Part`. Both, this state and its middleware will be part of an external framework, used by dozens of apps. Internally probably the
     `Middleware` will use `CoreLocation` to fetch the GPS changes, and triggers some actions. On the main app we have a global state, that we now
     call `Whole`.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, `Part` is a property of `Whole`, maybe not directly, it could be several nodes deep in the tree.

     Because our `Store` understands `Whole` and our `GPSMiddleware` understands `Part`, we must `lift(_:)` the middleware to the `Whole` level, by
     using:

     ```
     let globalStateMiddleware = gpsMiddleware.lift(stateMap: \MyGlobalState.currentLocation)
     ```

     Now this middleware can be used within our `Store` or even composed with others. It also can be used in other apps as long as we have a way to
     lift it to the world of `Whole`.

     - Parameters:
       - outputActionMap: a function that will translate the local actions dispatched by this middleware into a global action type for your store.
                          Usually this is wrapping the enum in a global action tree, such as
                          `{ GlobalAction.someSubAction(.middlewareLocalAction($0)) }`.
       - stateMap: a function that will translate the global state of your store into the local state of this middleware. Usually this is a KeyPath in
                   the global state struct, such as `\GlobalState.subState.middlewareLocalState`.
     - Returns: a `LiftMiddleware` that knows how to translate `Whole` to `Part` and vice-versa. To the external world this resulting middleware will
                "speak" global types to be plugged into the main Store. Internally it will "speak" the types of the wrapped middleware.
     */
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, Self>
    where GlobalInputActionType == InputActionType {
        .init(
            middleware: self,
            inputActionMap: { .some($0) },
            outputActionMap: outputActionMap,
            stateMap: stateMap
        )
    }

    /**
     A method used to transform a middleware focused in a specific substate into a middleware that can be plugged in a global scope and composed with
     other middlewares that work on different generic parameters. The global state of your app is *Whole*, and the `Middleware` handles *Part*, that
     is a sub-state.
     So for example you may want to have a `GPSMiddleware` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it `Part`. Both, this state and its middleware will be part of an external framework, used by dozens of apps. Internally probably the
     `Middleware` will use `CoreLocation` to fetch the GPS changes, and triggers some actions. On the main app we have a global state, that we now
     call `Whole`.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, `Part` is a property of `Whole`, maybe not directly, it could be several nodes deep in the tree.

     Because our `Store` understands `Whole` and our `GPSMiddleware` understands `Part`, we must `lift(_:)` the middleware to the `Whole` level, by
     using:

     ```
     let globalStateMiddleware = gpsMiddleware.lift(stateMap: \MyGlobalState.currentLocation)
     ```

     Now this middleware can be used within our `Store` or even composed with others. It also can be used in other apps as long as we have a way to
     lift it to the world of `Whole`.

     - Parameters:
       - inputActionMap: a function that will be executed every time a global action arrives at the global store. Then you can optionally return an
                         action of type Middleware's local input action type so the middleware will handle this action, or you can return nil in case
                         you want this middleware to ignore this global action. This is useful because not all middlewares will care about all global
                         actions. Usually this is a KeyPath in an enum, such as `\GlobalAction.someSubAction?.middlewareLocalAction` when you use code
                         generators to create enum properties.
       - stateMap: a function that will translate the global state of your store into the local state of this middleware. Usually this is a KeyPath in
                   the global state struct, such as `\GlobalState.subState.middlewareLocalState`.
     - Returns: a `LiftMiddleware` that knows how to translate `Whole` to `Part` and vice-versa. To the external world this resulting middleware will
                "speak" global types to be plugged into the main Store. Internally it will "speak" the types of the wrapped middleware.
     */
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, Self>
    where OutputActionType == GlobalOutputActionType {
        .init(
            middleware: self,
            inputActionMap: inputActionMap,
            outputActionMap: { $0 },
            stateMap: stateMap
        )
    }

    /**
     A method used to transform a middleware focused in a specific substate into a middleware that can be plugged in a global scope and composed with
     other middlewares that work on different generic parameters. The global state of your app is *Whole*, and the `Middleware` handles *Part*, that
     is a sub-state.
     So for example you may want to have a `GPSMiddleware` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it `Part`. Both, this state and its middleware will be part of an external framework, used by dozens of apps. Internally probably the
     `Middleware` will use `CoreLocation` to fetch the GPS changes, and triggers some actions. On the main app we have a global state, that we now
     call `Whole`.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, `Part` is a property of `Whole`, maybe not directly, it could be several nodes deep in the tree.

     Because our `Store` understands `Whole` and our `GPSMiddleware` understands `Part`, we must `lift(_:)` the middleware to the `Whole` level, by
     using:

     ```
     let globalStateMiddleware = gpsMiddleware.lift(stateMap: \MyGlobalState.currentLocation)
     ```

     Now this middleware can be used within our `Store` or even composed with others. It also can be used in other apps as long as we have a way to
     lift it to the world of `Whole`.

     - Parameters:
       - inputActionMap: a function that will be executed every time a global action arrives at the global store. Then you can optionally return an
                         action of type Middleware's local input action type so the middleware will handle this action, or you can return nil in case
                         you want this middleware to ignore this global action. This is useful because not all middlewares will care about all global
                         actions. Usually this is a KeyPath in an enum, such as `\GlobalAction.someSubAction?.middlewareLocalAction` when you use code
                         generators to create enum properties.
       - outputActionMap: a function that will translate the local actions dispatched by this middleware into a global action type for your store.
                          Usually this is wrapping the enum in a global action tree, such as
                          `{ GlobalAction.someSubAction(.middlewareLocalAction($0)) }`.
     - Returns: a `LiftMiddleware` that knows how to translate `Whole` to `Part` and vice-versa. To the external world this resulting middleware will
                "speak" global types to be plugged into the main Store. Internally it will "speak" the types of the wrapped middleware.
     */
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, Self>
    where GlobalStateType == StateType {
        .init(
            middleware: self,
            inputActionMap: inputActionMap,
            outputActionMap: outputActionMap,
            stateMap: { $0 }
        )
    }

    /**
     A method used to transform a middleware focused in a specific substate into a middleware that can be plugged in a global scope and composed with
     other middlewares that work on different generic parameters. The global state of your app is *Whole*, and the `Middleware` handles *Part*, that
     is a sub-state.
     So for example you may want to have a `GPSMiddleware` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it `Part`. Both, this state and its middleware will be part of an external framework, used by dozens of apps. Internally probably the
     `Middleware` will use `CoreLocation` to fetch the GPS changes, and triggers some actions. On the main app we have a global state, that we now
     call `Whole`.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, `Part` is a property of `Whole`, maybe not directly, it could be several nodes deep in the tree.

     Because our `Store` understands `Whole` and our `GPSMiddleware` understands `Part`, we must `lift(_:)` the middleware to the `Whole` level, by
     using:

     ```
     let globalStateMiddleware = gpsMiddleware.lift(stateMap: \MyGlobalState.currentLocation)
     ```

     Now this middleware can be used within our `Store` or even composed with others. It also can be used in other apps as long as we have a way to
     lift it to the world of `Whole`.

     - Parameters:
       - inputActionMap: a function that will be executed every time a global action arrives at the global store. Then you can optionally return an
                         action of type Middleware's local input action type so the middleware will handle this action, or you can return nil in case
                         you want this middleware to ignore this global action. This is useful because not all middlewares will care about all global
                         actions. Usually this is a KeyPath in an enum, such as `\GlobalAction.someSubAction?.middlewareLocalAction` when you use code
                         generators to create enum properties.
     - Returns: a `LiftMiddleware` that knows how to translate `Whole` to `Part` and vice-versa. To the external world this resulting middleware will
                "speak" global types to be plugged into the main Store. Internally it will "speak" the types of the wrapped middleware.
     */
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?
    ) -> LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, Self>
    where OutputActionType == GlobalOutputActionType, GlobalStateType == StateType {
        .init(
            middleware: self,
            inputActionMap: inputActionMap,
            outputActionMap: { $0 },
            stateMap: { $0 }
        )
    }

    /**
     A method used to transform a middleware focused in a specific substate into a middleware that can be plugged in a global scope and composed with
     other middlewares that work on different generic parameters. The global state of your app is *Whole*, and the `Middleware` handles *Part*, that
     is a sub-state.
     So for example you may want to have a `GPSMiddleware` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it `Part`. Both, this state and its middleware will be part of an external framework, used by dozens of apps. Internally probably the
     `Middleware` will use `CoreLocation` to fetch the GPS changes, and triggers some actions. On the main app we have a global state, that we now
     call `Whole`.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, `Part` is a property of `Whole`, maybe not directly, it could be several nodes deep in the tree.

     Because our `Store` understands `Whole` and our `GPSMiddleware` understands `Part`, we must `lift(_:)` the middleware to the `Whole` level, by
     using:

     ```
     let globalStateMiddleware = gpsMiddleware.lift(stateMap: \MyGlobalState.currentLocation)
     ```

     Now this middleware can be used within our `Store` or even composed with others. It also can be used in other apps as long as we have a way to
     lift it to the world of `Whole`.

     - Parameters:
       - outputActionMap: a function that will translate the local actions dispatched by this middleware into a global action type for your store.
                          Usually this is wrapping the enum in a global action tree, such as
                          `{ GlobalAction.someSubAction(.middlewareLocalAction($0)) }`.
     - Returns: a `LiftMiddleware` that knows how to translate `Whole` to `Part` and vice-versa. To the external world this resulting middleware will
                "speak" global types to be plugged into the main Store. Internally it will "speak" the types of the wrapped middleware.
     */
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, Self>
    where GlobalInputActionType == InputActionType, GlobalStateType == StateType {
        .init(
            middleware: self,
            inputActionMap: { .some($0) },
            outputActionMap: outputActionMap,
            stateMap: { $0 }
        )
    }

    /**
     A method used to transform a middleware focused in a specific substate into a middleware that can be plugged in a global scope and composed with
     other middlewares that work on different generic parameters. The global state of your app is *Whole*, and the `Middleware` handles *Part*, that
     is a sub-state.
     So for example you may want to have a `GPSMiddleware` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it `Part`. Both, this state and its middleware will be part of an external framework, used by dozens of apps. Internally probably the
     `Middleware` will use `CoreLocation` to fetch the GPS changes, and triggers some actions. On the main app we have a global state, that we now
     call `Whole`.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, `Part` is a property of `Whole`, maybe not directly, it could be several nodes deep in the tree.

     Because our `Store` understands `Whole` and our `GPSMiddleware` understands `Part`, we must `lift(_:)` the middleware to the `Whole` level, by
     using:

     ```
     let globalStateMiddleware = gpsMiddleware.lift(stateMap: \MyGlobalState.currentLocation)
     ```

     Now this middleware can be used within our `Store` or even composed with others. It also can be used in other apps as long as we have a way to
     lift it to the world of `Whole`.

     - Parameters:
       - stateMap: a function that will translate the global state of your store into the local state of this middleware. Usually this is a KeyPath in
                   the global state struct, such as `\GlobalState.subState.middlewareLocalState`.
     - Returns: a `LiftMiddleware` that knows how to translate `Whole` to `Part` and vice-versa. To the external world this resulting middleware will
                "speak" global types to be plugged into the main Store. Internally it will "speak" the types of the wrapped middleware.
     */
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        stateMap: @escaping (GlobalStateType) -> StateType
    ) -> LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, Self>
    where GlobalInputActionType == InputActionType, OutputActionType == GlobalOutputActionType {
        .init(
            middleware: self,
            inputActionMap: { .some($0) },
            outputActionMap: { $0 },
            stateMap: stateMap
        )
    }
}
