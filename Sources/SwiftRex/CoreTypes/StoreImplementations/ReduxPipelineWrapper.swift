import Foundation

public struct ReduxPipelineWrapper<ActionType, StateType>: ActionHandler {
    private let middleware: AnyMiddleware<ActionType, ActionType, StateType>
    private let reducer: Reducer<ActionType, StateType>
    private let emitsValue: ShouldEmitValue<StateType>
    private let getStatePublisher: () -> UnfailableReplayLastSubjectType<StateType>

    public init(
        getStatePublisher: @escaping () -> UnfailableReplayLastSubjectType<StateType>,
        reducer: Reducer<ActionType, StateType>,
        middleware: AnyMiddleware<ActionType, ActionType, StateType>,
        emitsValue: ShouldEmitValue<StateType>
    ) {
        DispatchQueue.setMainQueueID()
        self.middleware = middleware
        self.reducer = reducer
        self.getStatePublisher = getStatePublisher
        self.emitsValue = emitsValue

        middleware.receiveContext(
            getState: { getStatePublisher().value() },
            output: lazyActionHandler()
        )
    }

    private func lazyActionHandler() -> AnyActionHandler<ActionType> {
        .init { dispatchedAction in
            DispatchQueue.main.async {
                on(dispatchedAction: dispatchedAction)
            }
        }
    }

    public func dispatch(_ dispatchedAction: DispatchedAction<ActionType>) {
        DispatchQueue.asap {
            on(dispatchedAction: dispatchedAction)
        }
    }

    private func on(dispatchedAction: DispatchedAction<ActionType>) {
        var afterReducer: AfterReducer<ActionType> = .doNothing()
        middleware.handle(
            action: dispatchedAction.action,
            from: dispatchedAction.dispatcher,
            getState: { getStatePublisher().value() },
            afterReducer: &afterReducer
        )

        getStatePublisher().mutate(
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

        afterReducer.reducerIsDone(.init { dispatchedAction in
            dispatch(dispatchedAction)
        })
    }
}

extension ReduxPipelineWrapper where StateType: Equatable {
    public init(
        getStatePublisher: @escaping () -> UnfailableReplayLastSubjectType<StateType>,
        reducer: Reducer<ActionType, StateType>,
        middleware: AnyMiddleware<ActionType, ActionType, StateType>
    ) {
        self.init(getStatePublisher: getStatePublisher, reducer: reducer, middleware: middleware, emitsValue: .whenDifferent)
    }
}

extension ReduxPipelineWrapper where StateType: Equatable {
    public init<M: Middleware>(
        getStatePublisher: @escaping () -> UnfailableReplayLastSubjectType<StateType>,
        reducer: Reducer<ActionType, StateType>,
        middleware: M
    ) where M.StateType == StateType, M.InputActionType == ActionType, M.OutputActionType == ActionType {
        self.init(getStatePublisher: getStatePublisher, reducer: reducer, middleware: middleware.eraseToAnyMiddleware(), emitsValue: .whenDifferent)
    }
}

extension ReduxPipelineWrapper where StateType: Equatable {
    public init<M: MiddlewareProtocol>(
        getStatePublisher: @escaping () -> UnfailableReplayLastSubjectType<StateType>,
        reducer: Reducer<ActionType, StateType>,
        middleware: M
    ) where M.StateType == StateType, M.InputActionType == ActionType, M.OutputActionType == ActionType {
        self.init(getStatePublisher: getStatePublisher, reducer: reducer, middleware: middleware.eraseToAnyMiddleware(), emitsValue: .whenDifferent)
    }
}
