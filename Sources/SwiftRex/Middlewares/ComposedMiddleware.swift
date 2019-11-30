/**
 The `ComposedMiddleware` is a container of inner middlewares that are chained together in the order as they were composed. Whenever an `EventProtocol` or an `ActionProtocol` arrives to be handled by this `ComposedMiddleware`, it will delegate to its internal chain of middlewares.

 It could be initialized manually by using the `init()` and configured by using the method `append(middleware:)`, but if you're ok with using custom operators you can compose two or more middlewares using the diamond operator:

 ```
 let composedMiddleware = firstMiddleware <> secondMiddleware <> thirdMiddleware
 ```
 */
public final class ComposedMiddleware<InputActionType, OutputActionType, GlobalState>: Middleware {
    private var middlewares: [AnyMiddleware<InputActionType, OutputActionType, GlobalState>] = []

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
    public var context: () -> MiddlewareContext<OutputActionType, GlobalState> {
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
    public func append<M: Middleware>(middleware: M)
        where M.InputActionType == InputActionType,
              M.OutputActionType == OutputActionType,
              M.StateType == GlobalState {
        // Add in reverse order because we reduce from top to bottom and trigger from the last
        middleware.context = { [unowned self] in self.context() }
        // Inserts into the first position because the forward methods will work in the reverse order.
        // So the result for the user will be the expected, FIFO regardless the way we store the inner middlewares.
        middlewares.insert(AnyMiddleware(middleware), at: 0)
    }

    /**
     Handles the incoming actions. The `ComposedMiddleware` will forward each action to all its internal middlewares, in
     the order as they were composed together, and when all of them are done, the `ActionType` will be forwarded to the
     next middleware in the chain, or to the reducer pipeline in case this is the last middleware.

     The internal middlewares in this `ComposedMiddleware` container may trigger additional actions, as any middleware,
     and in this case the actions will be forwarded to the store by using the `context` property or the parent composed
     middleware object.
     - Parameters:
       - action: the action to be handled
       - next: opportunity to call the next middleware in the chain and, eventually, the reducer pipeline. Call it
               only once, not more or less than once. Call it from the same thread and runloop where the handle function
               is executed, never from a completion handler or dispatch queue block. In case you don't need to compare
               state before and after it's changed from the reducers, please consider to add a `defer` block with `next()`
               on it, at the beginning of `handle` function.
     */
    public func handle(action: InputActionType, next: @escaping Next) {
        let firstNode = middlewares
            .reversed()
            .reduce(next) { chain, middleware -> Next in {
                middleware.handle(action: action, next: chain)
            }
            }
        firstNode()
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
public func <> <M1: Middleware, M2: Middleware>(lhs: M1, rhs: M2) -> ComposedMiddleware < M1.InputActionType, M1.OutputActionType,
    M1.StateType>
    where M1.InputActionType == M2.InputActionType,
          M1.OutputActionType == M2.OutputActionType,
          M1.StateType == M2.StateType {
    let container = lhs as? ComposedMiddleware<M1.InputActionType, M1.OutputActionType, M1.StateType> ?? {
        let newContainer: ComposedMiddleware<M1.InputActionType, M1.OutputActionType, M1.StateType> = .init()
        newContainer.append(middleware: lhs)
        return newContainer
    }()

    container.append(middleware: rhs)
    return container
}
