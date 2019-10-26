import Foundation

public struct ReduxPipelineWrapper<MiddlewareType: Middleware>: ActionHandler
    where MiddlewareType.InputActionType == MiddlewareType.OutputActionType {
    public typealias ActionType = MiddlewareType.InputActionType
    public typealias StateType = MiddlewareType.StateType
    private let onAction: (ActionType) -> Void
    private let middleware: MiddlewareType

    public init(state: UnfailableReplayLastSubjectType<StateType>,
                reducer: Reducer<ActionType, StateType>,
                middleware: MiddlewareType,
                emitsValue: ShouldEmitValue<StateType>) {
        self.middleware = middleware

        let reduce: (ActionType) -> Void = { action in
            state.mutate(
                when: { $0 },
                action: { value -> Bool in
                    let newValue = reducer.reduce(action, value)
                    guard emitsValue.shouldEmit(previous: value, new: newValue) else { return false }
                    value = newValue
                    return true
                }
            )
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

extension ReduxPipelineWrapper where StateType: Equatable {
    public init(state: UnfailableReplayLastSubjectType<StateType>,
                reducer: Reducer<ActionType, StateType>,
                middleware: MiddlewareType) {
        self.init(state: state, reducer: reducer, middleware: middleware, emitsValue: .whenDifferent)
    }
}
