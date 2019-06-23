import SwiftRex

final class TestStore: StoreBase<TestState> {
    override init<M>(subject: UnfailableReplayLastSubjectType<StateType>,
                     reducer: Reducer<StateType>,
                     middleware: M) where StateType == M.StateType, M: Middleware {
        super.init(subject: subject, reducer: reducer, middleware: middleware)
    }
}
