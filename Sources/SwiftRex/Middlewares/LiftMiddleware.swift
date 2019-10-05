/**
 This is a container that lifts a sub-state middleware to a global state middleware.

 Internally you find the middleware responsible for handling events and actions for a sub-state (`Part`), while this outer class will be able to compose with global state (`Whole`) in your `Store`.

 You should not be able to instantiate this class directly, instead, create a middleware for the sub-state and call `Middleware.lift(_:)`, passing as parameter the keyPath from whole to part.
 */
public class LiftMiddleware<GlobalActionType, GlobalStateType, PartMiddleware: Middleware>: Middleware {
    typealias LocalActionType = PartMiddleware.ActionType
    typealias LocalStateType = PartMiddleware.StateType

    /**
     Every `Middleware` needs some context in order to be able to interface with other middleware and with the store.
     This context includes ways to fetch the most up-to-date state, dispatch new events or call the next middleware in
     the chain.

     For `SubstateMiddleware` this property is only a proxy call to the inner middleware's context, taking care of
     lifting `StateType` for all the function types inside.
     */
    public var context: () -> MiddlewareContext<GlobalActionType, GlobalStateType> {
        didSet {
            partMiddleware
                .context = { [unowned self] in
                    self.context()
                        .unlift(actionZoomOut: self.actionZoomOut, stateZoomIn: self.stateZoomIn)
                }
        }
    }

    private let partMiddleware: PartMiddleware
    private let actionZoomIn: (GlobalActionType) -> LocalActionType?
    private let actionZoomOut: (LocalActionType) -> GlobalActionType
    private let stateZoomIn: (GlobalStateType) -> LocalStateType

    init(middleware: PartMiddleware,
         actionZoomIn: @escaping (GlobalActionType) -> LocalActionType?,
         actionZoomOut: @escaping (LocalActionType) -> GlobalActionType,
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
     Handles the incoming actions and may change them or trigger additional ones. Usually this is not the best place to start side-effects or trigger new actions, it should be more as an observation point for tracking, logging and telemetry.
     - Parameters:
       - action: the action to be handled
       - getState: a function that can be used to get the current state at any point in time
       - next: the next `Middleware` in the chain, probably we want to call this method in some point of our method (not necessarily in the end. When this is the last middleware in the pipeline, the next function will call the `Reducer` pipeline.
     */
    public func handle(action: GlobalActionType, next: @escaping Next) {
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
    public func lift<GlobalActionType, GlobalStateType>(
        actionZoomIn: @escaping (GlobalActionType) -> ActionType?,
        actionZoomOut: @escaping (ActionType) -> GlobalActionType,
        stateZoomIn: @escaping (GlobalStateType) -> StateType
    ) -> LiftMiddleware<GlobalActionType, GlobalStateType, Self> {
        .init(middleware: self,
              actionZoomIn: actionZoomIn,
              actionZoomOut: actionZoomOut,
              stateZoomIn: stateZoomIn
        )
    }
}

extension MiddlewareContext {
    public func lift<GlobalActionType, GlobalStateType>(
        actionZoomIn: @escaping (GlobalActionType) -> ActionType?,
        stateZoomOut: @escaping (StateType) -> GlobalStateType)
        -> MiddlewareContext<GlobalActionType, GlobalStateType> {
        .init(
            onAction: { globalAction in
                guard let localAction = actionZoomIn(globalAction) else { return }
                self.dispatch(localAction)
            },
            getState: {
                stateZoomOut(self.getState())
            }
        )
    }

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
