//: [Previous](@previous)

import PlaygroundSwiftRexProxy
import CombineRex
import SwiftRex
import UIKit

// MARK: - State
struct AppState {
    let count: Int
}

// MARK: - Actions
enum AppAction {
    case increment
    case decrement
}

// MARK: - Reducers
let appReducer = Reducer<AppAction, AppState> { action, state in
    switch action {
    case .decrement:
        return AppState(count: state.count - 1)
    case .increment:
        return AppState(count: state.count + 1)
    }
}

// MARK: - Store
// Glue everything together
let store = ReduxStoreBase<AppAction, AppState>(
    subject: .combine(initialValue: AppState(count: 0)),
    reducer: appReducer,
    middleware: IdentityMiddleware() // <- No side-effects yet
)

let cancellable = store.statePublisher.sink {
    print("Got new state: \($0)")
}

store.dispatch(.increment)
store.dispatch(.increment)
store.dispatch(.decrement)
store.dispatch(.increment)
store.dispatch(.decrement)
store.dispatch(.decrement)
store.dispatch(.decrement)
store.dispatch(.increment)

//: [Next](@next)
