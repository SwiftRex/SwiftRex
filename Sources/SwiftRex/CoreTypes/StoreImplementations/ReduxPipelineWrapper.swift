import Foundation

public struct ReduxPipelineWrapper<MiddlewareType: Middleware>: ActionHandler
    where MiddlewareType.InputActionType == MiddlewareType.OutputActionType {
    public typealias ActionType = MiddlewareType.InputActionType
    public typealias StateType = MiddlewareType.StateType
    private let onAction: (ActionType) -> Void
    private let middleware: MiddlewareType

    public init(state: UnfailableReplayLastSubjectType<StateType>,
                reducer: Reducer<ActionType, StateType>,
                middleware: MiddlewareType) {
        self.middleware = middleware

        let reduce: (ActionType) -> Void = { action in
            state.mutate { value in
                value = reducer.reduce(action, value)
            }
        }

        let middlewarePipeline: (ActionType) -> Void = { [unowned middleware] action in
            middleware.handle(action: action, next: { reduce(action) })
        }

        let dispatchAction: (ActionType) -> Void = { action in
            DispatchQueue.main.async {
                middlewarePipeline(action)
            }
        }

        middleware.context = {
            .init(
                onAction: dispatchAction,
                getState: { state.value() }
            )
        }

        self.onAction = dispatchAction
    }

    public func dispatch(_ action: ActionType) {
        onAction(action)
    }
}
