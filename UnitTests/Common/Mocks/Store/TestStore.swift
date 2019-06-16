import SwiftRex

final class TestStore: StoreBase<TestState> {
    override init<M>(initialState: StateType,
                     reducer: Reducer<StateType>,
                     middleware: M) where StateType == M.StateType, M: Middleware {
        super.init(initialState: initialState, reducer: reducer, middleware: middleware)
    }
}
