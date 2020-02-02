import Foundation

public struct ReduxPipelineWrapper<MiddlewareType: Middleware>: ActionHandler
    where MiddlewareType.InputActionType == MiddlewareType.OutputActionType {
    public typealias ActionType = MiddlewareType.InputActionType
    public typealias StateType = MiddlewareType.StateType

    private var onAction: (ActionType) -> Void

    public init(
        state: UnfailableReplayLastSubjectType<StateType>,
        reducer: Reducer<ActionType, StateType>,
        middleware: MiddlewareType,
        emitsValue: ShouldEmitValue<StateType>
    ) {
        DispatchQueue.setMainQueueID()

        let onAction: (ActionType) -> Void = { action in
            let afterReducer = middleware.handle(action: action)

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

        middleware.receiveContext(
            getState: { state.value() },
            output: .init { action in
                DispatchQueue.main.async {
                    onAction(action)
                }
            }
        )

        self.onAction = onAction
    }

    public nonmutating func dispatch(_ action: ActionType) {
        DispatchQueue.asap {
            self.onAction(action)
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
