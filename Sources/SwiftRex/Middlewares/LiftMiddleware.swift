/**
 This is a container that lifts a sub-state middleware to a global state middleware.

 Internally you find the middleware responsible for handling events and actions for a sub-state (`Part`), while this outer class will be able to compose with global state (`Whole`) in your `Store`.

 You should not be able to instantiate this class directly, instead, create a middleware for the sub-state and call `Middleware.lift(_:)`, passing as parameter the keyPath from whole to part.
 */
public struct LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, PartMiddleware: MiddlewareProtocol>: MiddlewareProtocol {
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

    @available(
        *,
        deprecated,
        message: """
                 Instead of relying on receiveContext, please use the getState from handle(action) function,
                 and when returning IO from the same handle(action) function use the output from the closure
                 """
    )
    public func receiveContext(getState: @escaping () -> GlobalStateType, output: AnyActionHandler<GlobalOutputActionType>) {
        partMiddleware.receiveContext(
            getState: andThen(getState, stateMap),
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
       - dispatcher: information about the file, line and function that dispatched this action
       - state: a closure to obtain the most recent state
     - Returns: possible Side-Effects wrapped in an IO struct
     */
    public func handle(action: GlobalInputActionType, from dispatcher: ActionSource, state: @escaping GetState<GlobalStateType>)
    -> IO<GlobalOutputActionType> {
        guard let localAction: LocalInputActionType = inputActionMap(action) else {
            // This middleware doesn't care about this action type
            return .pure()
        }

        return partMiddleware
            .handle(action: localAction, from: dispatcher, state: { self.stateMap(state()) })
            .map(outputActionMap)
    }
}

/// a little helper to compose two functions
// swiftlint:disable:next identifier_name
private func andThen<A, B>(_ f: @escaping () -> A, _ g: @escaping (A) -> B) -> () -> B {
    { g(f()) }
}
