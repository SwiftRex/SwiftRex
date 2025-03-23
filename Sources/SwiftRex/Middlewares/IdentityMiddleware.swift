/**
 The `IdentityMiddleware` won't do any operation, simply bypass actions through. It's meant to provide identity axiom
 to middleware type to allow its conformance to monoid algebra. It will simply forward actions to the next middleware
 in the chain or to the reducers. It can be useful for Unit Tests or for some compositions.
 */
public struct IdentityMiddleware<InputActionType, OutputActionType, StateType>: MiddlewareProtocol, Equatable {
    /**
     Default initializer for `IdentityMiddleware`
     */
    public init() { }

    /**
     Handles the incoming actions and may or not start async tasks, check the latest state at any point or dispatch
     additional actions. This is also a good place for analytics, tracking, logging and telemetry.
     In this empty implementation, will do nothing but call next delegate.
     - Parameters:
       - action: the action to be handled
       - dispatcher: information about the file, line and function that dispatched this action
       - state: a closure to obtain the most recent state
     - Returns: possible Side-Effects wrapped in an IO struct
     */
    public func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType> {
        .pure()
    }
}
