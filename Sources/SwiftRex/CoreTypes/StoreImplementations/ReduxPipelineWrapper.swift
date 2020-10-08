import Foundation

public struct ReduxPipelineWrapper<MiddlewareType: Middleware>: ActionHandler
    where MiddlewareType.InputActionType == MiddlewareType.OutputActionType
{
    public typealias ActionType = MiddlewareType.InputActionType
    public typealias StateType = MiddlewareType.StateType

    private var onAction: (ActionType, ActionSource) -> Void
    private let middleware: MiddlewareWrapper

    private class MiddlewareWrapper {
        let middleware: MiddlewareType

        init(middleware: MiddlewareType) {
            self.middleware = middleware
        }
    }

    public init(
        state: UnfailableReplayLastSubjectType<StateType>,
        reducer: Reducer<ActionType, StateType>,
        middleware m: MiddlewareType,
        emitsValue: ShouldEmitValue<StateType>
    ) {
        DispatchQueue.setMainQueueID()
        let middlewareWrapper = MiddlewareWrapper(middleware: m)
        self.middleware = middlewareWrapper

        let onAction: (ActionType, ActionSource) -> Void = { [weak middlewareWrapper] action, dispatcher in
            var afterReducer: AfterReducer = .doNothing()
            middlewareWrapper?.middleware.handle(action: action, from: dispatcher, afterReducer: &afterReducer)

            state.mutate(
                when: { $0 },
                action: { value -> Bool in
                    let newValue = reducer.reduce(action, value)
                    guard emitsValue.shouldEmit(previous: value, new: newValue) else { return false }
                    value = newValue
                    return true
                }
            )

            afterReducer.reducerIsDone()
        }

        middlewareWrapper.middleware.receiveContext(
            getState: { state.value() },
            output: .init { action, dispatcher in
                DispatchQueue.main.async {
                    onAction(action, dispatcher)
                }
            }
        )

        self.onAction = onAction
    }

    public func dispatch(_ action: MiddlewareType.InputActionType, from dispatcher: ActionSource) {
        DispatchQueue.asap {
            self.onAction(action, dispatcher)
        }
    }
}

extension ReduxPipelineWrapper where StateType: Equatable {
    public init(
        state: UnfailableReplayLastSubjectType<StateType>,
        reducer: Reducer<ActionType, StateType>,
        middleware: MiddlewareType
    ) {
        self.init(state: state, reducer: reducer, middleware: middleware, emitsValue: .whenDifferent)
    }
}
