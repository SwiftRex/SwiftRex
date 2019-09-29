import SwiftRex

let createNameReducer: () -> Reducer<ActionMock, TestState> = {
    Reducer { (state: TestState, action) in
        switch action {
        case _ as Action1:
            var state = state
            state.name = "action1"
            return state
        case _ as Action2:
            var state = state
            state.name = "action2"
            return state
        default: return state
        }
    }
}
