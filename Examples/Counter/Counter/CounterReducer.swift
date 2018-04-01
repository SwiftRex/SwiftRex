import SwiftRex

struct CounterReducer: Reducer {
    func reduce(_ currentState: GlobalState, action: Action) -> GlobalState {
        guard let action = action as? CounterAction else { return currentState }

        var state = currentState

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
}
