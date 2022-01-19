/**
 This is a container that lifts a sub-state middleware to a global state middleware.
 
 Internally you find the middleware responsible for handling events and actions for a sub-state (`Part`), while this outer class will be able to compose with global state (`Whole`) in your `Store`.
 
 You should not be able to instantiate this class directly, instead, create a middleware for the sub-state and call `Middleware.liftToCollection(_:)`, passing as parameter the keyPath from whole to part.
 */
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct LiftToCollectionMiddleware<
    GlobalInputActionType,
    GlobalOutputActionType,
    GlobalStateType,
    CollectionState: MutableCollection,
    PartMiddleware: MiddlewareProtocol>: MiddlewareProtocol
where PartMiddleware.StateType: Identifiable, CollectionState.Element == PartMiddleware.StateType {
    private let partMiddleware: PartMiddleware
    private var actionHandler: (PartMiddleware,
                                GlobalInputActionType,
                                ActionSource,
                                @escaping GetState<GlobalStateType>) -> IO<GlobalOutputActionType>

    init(middleware: PartMiddleware,
         onAction: @escaping (PartMiddleware, GlobalInputActionType, ActionSource, @escaping GetState<GlobalStateType>) -> IO<GlobalOutputActionType>
    ) {
        self.partMiddleware = middleware
        self.actionHandler = onAction
    }

    @available(
        *,
         deprecated,
         message: """
                 This method is unavailable for this container type and won't do anything.
                 """
    )
    public func receiveContext(getState: @escaping () -> GlobalStateType, output: AnyActionHandler<GlobalOutputActionType>) {}

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
     - dispatcher: information about the file, line and function that dispatched this action
     - state: a closure to obtain the most recent state
     - Returns: possible Side-Effects wrapped in an IO struct
     */
    public func handle(action: GlobalInputActionType, from dispatcher: ActionSource, state: @escaping GetState<GlobalStateType>)
    -> IO<GlobalOutputActionType> {
        actionHandler(partMiddleware, action, dispatcher, state)
    }
}
