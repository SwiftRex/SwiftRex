import Foundation

public struct ReduxPipelineWrapper<MiddlewareType: Middleware>: ActionHandler
where MiddlewareType.InputActionType == MiddlewareType.OutputActionType {
    public typealias ActionType = MiddlewareType.InputActionType
    public typealias StateType = MiddlewareType.StateType

    private var onAction: (DispatchedAction<ActionType>) -> Void
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
        middleware: MiddlewareType,
        emitsValue: ShouldEmitValue<StateType>
    ) {
        DispatchQueue.setMainQueueID()
        let middlewareWrapper = MiddlewareWrapper(middleware: middleware)
        self.middleware = middlewareWrapper

        let onAction: (DispatchedAction<ActionType>) -> Void = { [weak middlewareWrapper] dispatchedAction in
            var afterReducer: AfterReducer = .doNothing()
            middlewareWrapper?.middleware.handle(action: dispatchedAction.action, from: dispatchedAction.dispatcher, afterReducer: &afterReducer)

            state.mutate(
                when: { $0 },
                action: { value in
                    switch emitsValue {
                    case .always:
                        reducer.reduce(dispatchedAction.action, &value)
                        return true
                    case .never:
                        return false
                    case let .when(predicate):
                        var newValue = value
                        reducer.reduce(dispatchedAction.action, &newValue)
                        guard predicate(value, newValue) else { return false }
                        value = newValue
                        return true
                    }
                }
            )

            afterReducer.reducerIsDone()
        }

        middlewareWrapper.middleware.receiveContext(
            getState: { state.value() },
            output: .init { dispatchedAction in
                DispatchQueue.main.async {
                    onAction(dispatchedAction)
                }
            }
        )

        self.onAction = onAction
    }

    public func dispatch(_ dispatchedAction: DispatchedAction<MiddlewareType.InputActionType>) {
        DispatchQueue.asap {
            self.onAction(dispatchedAction)
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
