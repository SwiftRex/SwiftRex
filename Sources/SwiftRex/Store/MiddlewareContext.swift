/**
 `MiddlewareContext` is a data structure that wraps an `EventHandler` and a `ActionHandler`, offering a way to dispatch events (`EventProtocol`) and trigger actions (`ActionProtocol`). This is usually the way how Middlewares will communicate both, actions and events, to Stores that will re-distribute them through its pipelines.
 */
public struct MiddlewareContext<ActionType, StateType> {
    /**
     A way for Middlewares to trigger new actions.
     */
    public let actionHandler: ActionHandler<ActionType>

    /**
     A way for Middlewares to fetch the latest state.
     */
    public let getState: GetState<StateType>

    /**
     A way for Middlewares to fetch the latest state.
     */
    public var next: NextActionHandler<ActionType>

    public init(actionHandler: ActionHandler<ActionType>,
                getState: @escaping GetState<StateType>,
                next: @escaping NextActionHandler<ActionType>) {
        self.actionHandler = actionHandler
        self.getState = getState
        self.next = next
    }
}

extension MiddlewareContext {
    public func lift<GlobalActionType, GlobalStateType>(
        actionContramap: @escaping (GlobalActionType) -> ActionType,
        stateMap: @escaping (StateType) -> GlobalStateType)
        -> MiddlewareContext<GlobalActionType, GlobalStateType> {
        MiddlewareContext<GlobalActionType, GlobalStateType>(
            actionHandler: .init(
                onValue: { globalAction in
                    let localAction = actionContramap(globalAction)
                    self.actionHandler.onValue(localAction)
                },
                onCompleted: self.actionHandler.onCompleted
            ),
            getState: { () -> GlobalStateType in
                stateMap(self.getState())
            },
            next: { (action: GlobalActionType) -> Void in
                self.next(actionContramap(action))
            }
        )
    }
}
