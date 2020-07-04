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

    init(middleware: PartMiddleware,
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
