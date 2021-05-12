public protocol MiddlewareProtocol {
    /**
     The Action type that this `Middleware` knows how to handle, so the store will forward actions of this type to this middleware.
     Thanks to optics, this action can be a sub-action lifted to a global action type in order to compose with other middlewares acting on the global
     action of an app. Please check `lift(inputActionMap:outputActionMap:stateMap:)` for more details.
     */
    associatedtype InputActionType

    /**
     The Action type that this `Middleware` will eventually trigger back to the store in response of side-effects. This can be the same as
     `InputActionType` or different, in case you want to separate your enum in requests and responses.
     Thanks to optics, this action can be a sub-action lifted to a global action type in order to compose with other middlewares acting on the global
     action of an app. Please check `lift(inputActionMap:outputActionMap:stateMap:)` for more details.
     */
    associatedtype OutputActionType

    /**
     The State part that this `Middleware` needs to read in order to make decisions. This middleware will be able to read the most up-to-date
     `StateType` from the store at any point in time, but it can never write or make changes to it. In some cases, middleware don't need reading the
     whole global state, so we can decide to allow only a sub-state, or maybe this middleware doesn't need to read any state, so the `StateType`can
     safely be set to `Void`.
     Thanks to lenses, this state can be a sub-state lifted to a global state in order to compose with other middlewares acting on the global state
     of an app. Please check `lift(inputActionMap:outputActionMap:stateMap:)` for more details.
     */
    associatedtype StateType

    func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType>

    /**
     Middleware setup. This function will be called before actions are handled to the middleware, so you can configure your middleware with the given
     parameters. You can hold any of them if you plan to read the state or dispatch new actions.
     You can initialize and start timers or async tasks in here or in the `handle(action:next)` function, but never before this function is called,
     otherwise the middleware would not yet be running from a store.
     Because no actions are delivered to this middleware before the `receiveContext(getState:output:)` is called, you can safely keep implicit
     unwrapped versions of `getState` and `output` as properties of your concrete middleware, and set them from the arguments of this function.

     - Parameters:
       - getState: a closure that allows the middleware to read the current state at any point in time
       - output: an action handler that allows the middleware to dispatch new actions at any point in time
     */
    @available(
        *,
        deprecated,
        message: """
                 Instead of relying on receiveContext, please use the getState from handle(action) function,
                 and when returning IO from the same handle(action) function use the output from the closure
                 """
    )
    func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>)
}

extension MiddlewareProtocol {
    @available(
        *,
        deprecated,
        message: """
                 Instead of relying on receiveContext, please use the getState from handle(action) function,
                 and when returning IO from the same handle(action) function use the output from the closure
                 """
    )
    public func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>) {
    }
}

// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = StateType
// sourcery: AutoMockableGeneric = OutputActionType
// sourcery: AutoMockableGeneric = InputActionType
extension MiddlewareProtocol { }
