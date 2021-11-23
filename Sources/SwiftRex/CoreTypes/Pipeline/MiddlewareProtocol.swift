/// ``MiddlewareProtocol`` is a plugin, or a composition of several plugins, that are assigned to the app global ``StoreType`` pipeline in order to
/// handle each action received (``InputActionType``), to execute side-effects in response, and eventually dispatch more actions
/// (``OutputActionType``) in the process. It can also access the most up-to-date ``StateType`` while handling an incoming action.
public protocol MiddlewareProtocol {
    /// The Action type that this ``MiddlewareProtocol`` knows how to handle, so the store will forward actions of this type to this middleware.
    ///
    /// Most of the times middlewares don't need to handle all possible actions from the whole global action tree, so we can decide to allow it to
    /// focus only on a subset of the action.
    ///
    /// In this case, this action type can be a subset to be lifted to a global action type in order to compose with other middlewares acting on the
    /// global action of an app. Please check <doc:Lifting> for more details.
    associatedtype InputActionType

    /// The Action type that this ``MiddlewareProtocol`` will eventually trigger back to the store in response of side-effects. This can be the same
    /// as ``InputActionType`` or different, in case you want to separate your enum in requests and responses.
    ///
    /// Most of the times middlewares don't need to dispatch all possible actions of the whole global action tree, so we can decide to allow it to
    /// dispatch only a subset of the action, or not dispatch any action at all, so the ``OutputActionType`` can safely be set to `Never`.
    ///
    /// In this case, this action type can be a subset to be lifted to a global action type in order to compose with other middlewares acting on the
    /// global action of an app. Please check <doc:Lifting> for more details.
    associatedtype OutputActionType

    /// The State part that this ``MiddlewareProtocol`` needs to read in order to make decisions. This middleware will be able to read the most
    /// up-to-date ``StateType`` from the store while handling an incoming action, but it can never write or make changes to it.
    ///
    /// Most of the times middlewares don't need reading the whole global state, so we can decide to allow it to read only a subset of the state, or
    /// maybe this middleware doesn't need to read any state, so the ``StateType`` can safely be set to `Void`.
    ///
    /// In this case, this state type can be a subset to be lifted to a global state in order to compose with other middlewares acting on the global state
    /// of an app. Please check <doc:Lifting> for more details.
    associatedtype StateType

    /// Handles the incoming actions and may or not start async tasks, check the latest state at any point or dispatch additional actions.
    ///
    /// This is a good place for side-effects such as async tasks, timers, web, database, file access, background execution, access device sensors,
    /// perform analytics, tracking, logging and telemetry. You can schedule tasks to run after the reducer changed the global state, this will happen
    /// in the ``IO`` closure you must return from this function.
    ///
    /// In case no side-effect is required for certain action, returning ``IO/pure()`` should suffice.
    ///
    /// You can only dispatch new actions to the store from inside the ``IO`` closure.
    ///
    /// > **_IMPORTANT:_** this will be called on the main queue, never perform expensive work on it. You should perform side-effects only in the
    /// ``IO`` block and care about running things in background. You don't have to return to the main queue to dispatch actions, however, the store
    /// will take care of that.
    ///
    /// - Parameters:
    ///   - action: the incoming action to be handled
    ///   - dispatcher: information about the action source, representing the entity that created and dispatched the action
    ///   - state: a closure that, once called, will return the most up-to-date state. In the scope of this function, the state wasn't handled by
    ///            reducers yet, but in the context of the ``IO`` block you should expect the state to be changed already.
    /// - Returns: an ``IO`` closure where you can run side-effects and dispatch new actions to the store
    func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType>

    /// Middleware setup. This function is deprecated and should never be used.
    ///
    /// - Parameters:
    ///   - getState: a closure that allows the middleware to read the current state at any point in time
    ///   - output: an action handler that allows the middleware to dispatch new actions at any point in time
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
