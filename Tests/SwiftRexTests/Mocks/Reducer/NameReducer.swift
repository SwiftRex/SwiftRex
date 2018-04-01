import RxSwift
@testable import SwiftRex
import XCTest

struct NameReducer: Reducer {
    func reduce(_ currentState: TestState, action: Action) -> TestState {
        switch action {
        case _ as Action1:
            var state = currentState
            state.name = "action1"
            return state
        case _ as Action2:
            var state = currentState
            state.name = "action2"
            return state
        default: return currentState
        }
    }
}
