import SwiftRex

final class TestStore: StoreBase<ActionMock, TestState> {
    override init<M>(subject: UnfailableReplayLastSubjectType<StateType>,
                     reducer: Reducer<ActionMock, StateType>,
                     middleware: M) where ActionType == M.ActionType, StateType == M.StateType, M: Middleware {
        super.init(subject: subject, reducer: reducer, middleware: middleware)
    }
}
