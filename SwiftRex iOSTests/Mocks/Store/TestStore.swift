import RxSwift
@testable import SwiftRex
import XCTest

final class TestStore: StoreBase<TestState> {
    typealias E = TestState

    override init<R, M>(initialState: E, reducer: R, middleware: M) where E == R.StateType, R: Reducer, M: Middleware, R.StateType == M.StateType {
        super.init(initialState: initialState, reducer: reducer, middleware: middleware)
    }
}
