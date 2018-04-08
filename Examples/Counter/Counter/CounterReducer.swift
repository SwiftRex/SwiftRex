import SwiftRex

let counterReducer = Reducer<GlobalState> { state, action in
    guard let action = action as? CounterAction else { return state }

    var state = state

    switch action {
    case .increaseValue:
        state.value += 1
    case .decreaseValue:
        state.value -= 1
    case .setLoading(let isLoading):
        state.isLoading = isLoading
    }

    return state
}
