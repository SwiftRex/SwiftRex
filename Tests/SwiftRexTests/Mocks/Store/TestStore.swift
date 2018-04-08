import RxSwift
@testable import SwiftRex
import XCTest

final class TestStore: StoreBase<TestState> {
    override init<M>(initialState: TestState, reducer: Reducer<TestState>, middleware: M) where M.StateType == TestState, M: Middleware {
        super.init(initialState: initialState, reducer: reducer, middleware: middleware)
    }
}
