import SwiftRex

let createReducerMock: () -> (Reducer<AppAction, TestState>, ReducerMock<AppAction, TestState>) = {
    let mock = ReducerMock<AppAction, TestState>()

    return (Reducer { action, state in
        mock.reduceCallsCount += 1
        mock.reduceReceivedArguments = (action: action, currentState: state)
        return mock.reduceClosure.map { $0(action, state) } ?? mock.reduceReturnValue
    }, mock)
}

class ReducerMock<ActionType, StateType> {
    // MARK: - reduce

    var reduceCallsCount = 0
    var reduceCalled: Bool {
        reduceCallsCount > 0
    }
    var reduceReceivedArguments: (action: ActionType, currentState: StateType)?
    var reduceReturnValue: StateType!
    var reduceClosure: ((ActionType, StateType) -> StateType)?
}
