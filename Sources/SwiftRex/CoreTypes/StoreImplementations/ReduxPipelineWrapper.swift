import Foundation

public struct ReduxPipelineWrapper<MiddlewareType: MiddlewareProtocol>: ActionHandler
where MiddlewareType.InputActionType == MiddlewareType.OutputActionType {
    public typealias ActionType = MiddlewareType.InputActionType
    public typealias StateType = MiddlewareType.StateType

    private let state: () -> UnfailableReplayLastSubjectType<StateType>
    private let reducer: Reducer<ActionType, StateType>
    private let middleware: MiddlewareType
    private let emitsValue: ShouldEmitValue<StateType>

    public init(
        state: @escaping () -> UnfailableReplayLastSubjectType<StateType>,
        reducer: Reducer<ActionType, StateType>,
        middleware: MiddlewareType,
        emitsValue: ShouldEmitValue<StateType>
    ) {
        DispatchQueue.setMainQueueID()
        self.state = state
        self.reducer = reducer
        self.middleware = middleware
        self.emitsValue = emitsValue

        middleware.receiveContext(
            getState: { state().value() },
            output: self.eraseToAnyActionHandler()
        )
    }

    public func dispatch(_ dispatchedAction: DispatchedAction<MiddlewareType.InputActionType>) {
        handleAsap(dispatchedAction: dispatchedAction)
    }

    private func handleNextRunLoop(dispatchedAction: DispatchedAction<MiddlewareType.InputActionType>) {
        DispatchQueue.main.async {
            self.handle(dispatchedAction: dispatchedAction)
        }
    }

    private func handleAsap(dispatchedAction: DispatchedAction<MiddlewareType.InputActionType>) {
        DispatchQueue.asap {
            self.handle(dispatchedAction: dispatchedAction)
        }
    }

    private func handle(dispatchedAction: DispatchedAction<MiddlewareType.InputActionType>) {
        let io = middleware.handle(action: dispatchedAction.action, from: dispatchedAction.dispatcher, state: { state().value() })

        state().mutate(
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

        io.runIO(self.eraseToAnyActionHandler())
    }
}

extension ReduxPipelineWrapper where StateType: Equatable {
    public init(
        state: @escaping () -> UnfailableReplayLastSubjectType<StateType>,
        reducer: Reducer<ActionType, StateType>,
        middleware: MiddlewareType
    ) {
        self.init(state: state, reducer: reducer, middleware: middleware, emitsValue: .whenDifferent)
    }
}
