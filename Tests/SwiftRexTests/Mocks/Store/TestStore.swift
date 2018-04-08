import RxSwift
@testable import SwiftRex
import XCTest

final class TestStore: StoreBase<TestState> {
    required init<M>(initialState: E, reducer: Reducer<E>, middleware: M) where E == M.StateType, M: Middleware {
        super.init(initialState: initialState, reducer: reducer, middleware: middleware)
    }
}
