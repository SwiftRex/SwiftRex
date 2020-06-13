import PlaygroundSwiftRexProxy
import CombineRex
import SwiftRex
import UIKit

// MARK: - State
struct AppState {
    var count: Int
}

// MARK: - Actions
enum AppAction {
    case count(CountAction)

    // This is not required, and can be code-generated
    // But it's recommended for easy liftling
    public var count: CountAction? {
        get {
            guard case let .count(value) = self else { return nil }
            return value
        }
        set {
            guard case .count = self, let newValue = newValue else { return }
            self = .count(newValue)
        }
    }
}

enum CountAction {
    case increment
    case decrement
}

// MARK: - Reducers
let counterReducer = Reducer<CountAction, Int> { action, state in
    switch action {
    case .decrement:
        return state - 1
    case .increment:
        return state + 1
    }
}

let appReducer = counterReducer.lift(
    action: \AppAction.count,
    state: \AppState.count
)

// MARK: - Store
let store = ReduxStoreBase<AppAction, AppState>(
    subject: .combine(initialValue: AppState(count: 0)),
    reducer: appReducer,
    middleware: IdentityMiddleware()
)

store.statePublisher.sink {
    print("Got new state: \($0)")
}

store.dispatch(.count(.increment))
store.dispatch(.count(.increment))
store.dispatch(.count(.decrement))
store.dispatch(.count(.increment))
store.dispatch(.count(.decrement))
store.dispatch(.count(.decrement))
store.dispatch(.count(.decrement))
store.dispatch(.count(.increment))
