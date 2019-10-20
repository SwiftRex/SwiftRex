/**
 This is a container that lifts a sub-state middleware to a global state middleware.

 Internally you find the middleware responsible for handling events and actions for a sub-state (`Part`), while this outer class will be able to compose with global state (`Whole`) in your `Store`.

 You should not be able to instantiate this class directly, instead, create a middleware for the sub-state and call `Middleware.lift(_:)`, passing as parameter the keyPath from whole to part.
 */
public class LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, PartMiddleware: Middleware>: Middleware {
    typealias LocalInputActionType = PartMiddleware.InputActionType
    typealias LocalOutputActionType = PartMiddleware.OutputActionType
    typealias LocalStateType = PartMiddleware.StateType

    /**
     Every `Middleware` needs some context in order to be able to interface with other middleware and with the store.
     This context includes ways to fetch the most up-to-date state, dispatch new events or call the next middleware in
     the chain.

     For `SubstateMiddleware` this property is only a proxy call to the inner middleware's context, taking care of
     lifting `StateType` for all the function types inside.
     */
    public var context: () -> MiddlewareContext<GlobalOutputActionType, GlobalStateType> {
        didSet {
            partMiddleware
                .context = { [unowned self] in
                    self.context()
                        .unlift(actionZoomOut: self.actionZoomOut, stateZoomIn: self.stateZoomIn)
                }
        }
    }

    private let partMiddleware: PartMiddleware
    private let actionZoomIn: (GlobalInputActionType) -> LocalInputActionType?
    private let actionZoomOut: (LocalOutputActionType) -> GlobalOutputActionType
    private let stateZoomIn: (GlobalStateType) -> LocalStateType

    init(middleware: PartMiddleware,
         actionZoomIn: @escaping (GlobalInputActionType) -> LocalInputActionType?,
         actionZoomOut: @escaping (LocalOutputActionType) -> GlobalOutputActionType,
         stateZoomIn: @escaping (GlobalStateType) -> LocalStateType) {
        self.actionZoomIn = actionZoomIn
        self.actionZoomOut = actionZoomOut
        self.stateZoomIn = stateZoomIn
        self.partMiddleware = middleware
        self.context = {
            fatalError("No context set for middleware LiftMiddleware, please be sure to configure your middleware prior to usage")
        }
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
    public func handle(action: GlobalInputActionType, next: @escaping Next) {
        guard let actionSubpart = actionZoomIn(action) else {
            next()
            return
        }

        partMiddleware.handle(action: actionSubpart, next: next)
    }
}

extension Middleware {
    /**
     A lenses method. The global state of your app is *Whole*, and the `Middleware` handles *Part*, that is a sub-state.
     So for example you may want to have a `GPSMiddleware` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it `Part`. Both, this state and its middleware will be part of an external framework, used by dozens of apps. Internally probably the `Middleware` will use `CoreLocation` to fetch the GPS changes, and triggers some actions. On the main app we have a global state, that we now call `Whole`.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, `Part` is a property of `Whole`, maybe not directly, it could be several nodes deep in the tree.

     Because our `Store` understands `Whole` and our `GPSMiddleware` understands `Part`, we must `lift(_:)` the middleware to the `Whole` level, by using:

     ```
     let globalStateMiddleware = gpsMiddleware.lift(\MyGlobalState.currentLocation)
     ```

     Now this middleware can be used within our `Store` or even composed with others. It also can be used in other apps as long as we have a way to lift it to the world of `Whole`.

     - Parameter substatePath: the keyPath that goes from `Whole` to `Part`
     - Returns: a `SubstateMiddleware``<Whole, Self>` that knows how to translate `Whole` to `Part` and vice-versa, by using the key path.
     */
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        actionZoomIn: @escaping (GlobalInputActionType) -> InputActionType?,
        actionZoomOut: @escaping (OutputActionType) -> GlobalOutputActionType,
        stateZoomIn: @escaping (GlobalStateType) -> StateType
    ) -> LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, Self> {
        .init(
            middleware: self,
            actionZoomIn: actionZoomIn,
            actionZoomOut: actionZoomOut,
            stateZoomIn: stateZoomIn
        )
    }
}

extension MiddlewareContext {
    public func unlift<LocalActionType, LocalStateType>(
        actionZoomOut: @escaping (LocalActionType) -> ActionType,
        stateZoomIn: @escaping (StateType) -> LocalStateType)
        -> MiddlewareContext<LocalActionType, LocalStateType> {
        .init(
            onAction: { localAction in
                let globalAction = actionZoomOut(localAction)
                self.dispatch(globalAction)
            },
            getState: {
                stateZoomIn(self.getState())
            }
        )
    }
}
