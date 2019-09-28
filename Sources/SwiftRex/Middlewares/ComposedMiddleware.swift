// swiftlint:disable opening_brace

/**
 The `ComposedMiddleware` is a container of inner middlewares that are chained together in the order as they were composed. Whenever an `EventProtocol` or an `ActionProtocol` arrives to be handled by this `ComposedMiddleware`, it will delegate to its internal chain of middlewares.

 It could be initialized manually by using the `init()` and configured by using the method `append(middleware:)`, but if you're ok with using custom operators you can compose two or more middlewares using the diamond operator:

 ```
 let composedMiddleware = firstMiddleware <> secondMiddleware <> thirdMiddleware
 ```
 */
public final class ComposedMiddleware<GlobalState>: Middleware {
    private var middlewares: [AnyMiddleware<GlobalState>] = []

    /**
     Default initializer for `ComposedMiddleware`, use this only if you don't like custom operators, otherwise create a `ComposedMiddleware` by composing two or more middlewares using the diamond operator, as shown below:
     ```
     let composedMiddleware = firstMiddleware <> secondMiddleware
     ```
     */
    public init() {
        self.context = {
            fatalError("No context set for middleware PipelineMiddleware, please be sure to configure your middleware prior to usage")
        }
    }

    /**
     Every `Middleware` needs some context in order to be able to interface with other middleware and with the store.
     This context includes ways to fetch the most up-to-date state, dispatch new events or call the next middleware in
     the chain.

     A `ComposedMiddleware` also sets its child middlewares to the same context whenever this property is set.
     */
    public var context: () -> MiddlewareContext {
        didSet {
            middlewares.forEach {
                $0.context = { [unowned self] in self.context() }
            }
        }
    }

    /**
     Appends a new middleware to end of the composition (inner chain). Use this only if you don't like custom operators, otherwise create a `ComposedMiddleware` append more middlewares to the composition by using the diamond operator, as shown below:
     ```
     let composedOfThreeMiddlewares = composedOfTwoMiddlewares <> thirdMiddleware
     ```

     Or

     ```
     let composedOfThreeMiddlewares = firstMiddleware <> secondMiddleware <> thirdMiddleware
     ```
     */
    public func append<M: Middleware>(middleware: M) where M.StateType == GlobalState {
        // Add in reverse order because we reduce from top to bottom and trigger from the last
        middleware.context = { [unowned self] in self.context() }
        // Inserts into the first position because the forward methods will work in the reverse order.
        // So the result for the user will be the expected, FIFO regardless the way we store the inner middlewares.
        middlewares.insert(AnyMiddleware(middleware), at: 0)
    }

    /**
     Handles the incoming events. The `ComposedMiddleware` will call `handle(event:getState:next:)` for all its internal middlewares, in the order as they were composed and when all of them are done, the `EventProtocol` will be forwarded to the next middleware in the chain.

     The internal middlewares in this `ComposedMiddleware` container may trigger side-effects, may trigger actions, may start an asynchronous operation.

     - Parameters:
       - event: the event to be handled
       - getState: a function that can be used to get the current state at any point in time
       - next: the next `Middleware in the chain, probably we want to call this method in some point of our method (not necessarily in the end.
     */
    public func handle(event: EventProtocol, getState: @escaping GetState<GlobalState>, next: @escaping NextEventHandler<GlobalState>) {
        let chain = middlewares.reduce(next) { nextHandler, middleware in
            { (chainEvent: EventProtocol, chainGetState: @escaping GetState<GlobalState>) in
                middleware.handle(event: chainEvent, getState: chainGetState, next: nextHandler)
            }
        }
        chain(event, getState)
    }

    /**
     Handles the incoming actions. The `ComposedMiddleware` will call `handle(action:getState:next:)` for all its internal middlewares, in the order as they were composed and when all of them are done, the `ActionProtocol` will be forwarded to the next middleware in the chain.

     The internal middlewares in this `ComposedMiddleware` container may change the `ActionProtocol` or trigger additional ones. Usually this is not the best place to start side-effects or trigger new actions, it should be more as an observation point for tracking, logging and telemetry.
     - Parameters:
       - action: the action to be handled
       - getState: a function that can be used to get the current state at any point in time
       - next: the next `Middleware` in the chain, probably we want to call this method in some point of our method (not necessarily in the end. When this is the last middleware in the pipeline, the next function will call the `Reducer` pipeline.
     */
    public func handle(action: ActionProtocol, getState: @escaping GetState<GlobalState>, next: @escaping NextActionHandler<GlobalState>) {
        let chain = middlewares.reduce(next) { nextHandler, middleware in
            { (chainAction: ActionProtocol, chainGetState: @escaping GetState<GlobalState>) in
                middleware.handle(action: chainAction, getState: chainGetState, next: nextHandler)
            }
        }
        chain(action, getState)
    }
}

/**
 Initializes a `ComposedMiddleware` from the `lhs` and `rhs` middlewares parameters, or appends to the `lhs` if it is already a `ComposedMiddleware`, as shown below:

 ```
 let composedOfThreeMiddlewares = composedOfTwoMiddlewares <> thirdMiddleware
 ```

 Or

 ```
 let composedOfThreeMiddlewares = firstMiddleware <> secondMiddleware <> thirdMiddleware
 ```

 Or

 ```
 let composedMiddlewares = firstMiddleware <> secondMiddleware
 _ = composedMiddlewares <> thirdMiddleware
 // assert(composedMiddlewares == firstMiddleware <> secondMiddleware <> thirdMiddleware)
 ```

 - Parameters:
   - lhs: A flat middleware or a composed middleware, in case it's a flat one, this operation will create a new `ComposedMiddleware` and return it, otherwise it will append the `rhs` to this composed lhs one mutating it and also returning it.
   - rhs: A flat middleware to be appended to the end of a `ComposedMiddleware`
 - Returns: A `ComposedMiddleware` that calls the `lhs` methods before the `rhs` ones. If `lhs` is already a `ComposedMiddleware`, we will return the same instance after mutating it to have the `rhs` in the end of its chain.
 */
public func <> <M1: Middleware, M2: Middleware> (lhs: M1, rhs: M2) -> ComposedMiddleware<M1.StateType> where M1.StateType == M2.StateType {
    let container = lhs as? ComposedMiddleware<M1.StateType> ?? {
        let newContainer: ComposedMiddleware<M1.StateType> = .init()
        newContainer.append(middleware: lhs)
        return newContainer
    }()

    container.append(middleware: rhs)
    return container
}
