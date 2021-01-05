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
     let globalStateMiddleware = gpsMiddleware.lift(state: \MyGlobalState.currentLocation)
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
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> StateType
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
     let globalStateMiddleware = gpsMiddleware.lift(state: \MyGlobalState.currentLocation)
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
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> StateType
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
     let globalStateMiddleware = gpsMiddleware.lift(state: \MyGlobalState.currentLocation)
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
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        state stateMap: @escaping (GlobalStateType) -> StateType
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
     let globalStateMiddleware = gpsMiddleware.lift(state: \MyGlobalState.currentLocation)
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
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
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
     let globalStateMiddleware = gpsMiddleware.lift(state: \MyGlobalState.currentLocation)
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
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?
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
     let globalStateMiddleware = gpsMiddleware.lift(state: \MyGlobalState.currentLocation)
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
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
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
     let globalStateMiddleware = gpsMiddleware.lift(state: \MyGlobalState.currentLocation)
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
        state stateMap: @escaping (GlobalStateType) -> StateType
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
