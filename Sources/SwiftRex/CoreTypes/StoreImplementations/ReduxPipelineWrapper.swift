import Foundation

public class ReduxPipelineWrapper<MiddlewareType: MiddlewareProtocol>: ActionHandler
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
            output: .init { [weak self] dispatchedAction in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    let io = Self.handle(
                        middleware: self.middleware,
                        reducer: reducer,
                        dispatchedAction: dispatchedAction,
                        state: state,
                        emitsValue: emitsValue
                    )
                    Self.runIO(io) { [weak self] action in
                        self?.handleAsap(dispatchedAction: action)
                    }
                }
            }
        )
    }

    public func dispatch(_ dispatchedAction: DispatchedAction<ActionType>) {
        handleAsap(dispatchedAction: dispatchedAction)
    }

    private func handleAsap(dispatchedAction: DispatchedAction<ActionType>) {
        DispatchQueue.asap {
            let io = Self.handle(
                middleware: self.middleware,
                reducer: self.reducer,
                dispatchedAction: dispatchedAction,
                state: self.state,
                emitsValue: self.emitsValue
            )

            Self.runIO(io, handler: { [weak self] dispatchedAction in self?.dispatch(dispatchedAction) })
        }
    }

    private static func handle(
        middleware: MiddlewareType,
        reducer: Reducer<ActionType, StateType>,
        dispatchedAction: DispatchedAction<ActionType>,
        state: @escaping () -> UnfailableReplayLastSubjectType<StateType>,
        emitsValue: ShouldEmitValue<StateType>
    ) -> IO<ActionType> {
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

        return io
    }

    private static func runIO(_ io: IO<ActionType>, handler: @escaping (DispatchedAction<ActionType>) -> Void) {
        io.run(.init { dispatchedAction in
            handler(dispatchedAction)
        })
    }
}

extension ReduxPipelineWrapper where StateType: Equatable {
    public convenience init(
        state: @escaping () -> UnfailableReplayLastSubjectType<StateType>,
        reducer: Reducer<ActionType, StateType>,
        middleware: MiddlewareType
    ) {
        self.init(state: state, reducer: reducer, middleware: middleware, emitsValue: .whenDifferent)
    }
}
