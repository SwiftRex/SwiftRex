//: [Previous](@previous)

import PlaygroundSwiftRexProxy
import CombineRex
import SwiftRex
import UIKit

// MARK: - State
// AppState can take care of other domains, like user logged-in, user preferences, etc.
// Count state (Int) is only one of its domains.
struct AppState {
    var count: Int
}

// MARK: - Actions
// AppAction can take care of other domains, like app events (background, active, device orientation, etc).
// CountAction is only one of its domains.
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

// CountAction is specific for actions related to counter
enum CountAction {
    case increment
    case decrement
}

// MARK: - Reducers
// Counter reducer works in a tight domain of CountActions and current count state (Int)
// On decrement, we return the state decreased by 1, on increment, we return it increased by 1.
let counterReducer = Reducer<CountAction, Int> { action, state in
    switch action {
    case .decrement:
        return state - 1
    case .increment:
        return state + 1
    }
}

// App reducers will take all known reducers and one by one compose them
// If the work in a tight domain, we lift them to the AppAction+AppState domain
// by simply using keypaths. That's where those code-generated enum properties are handy.
let appReducer = counterReducer.lift(
    action: \AppAction.count, // <- given an AppAction, how to define whether is a CounterAction?
    state: \AppState.count    // <- given an AppState, how to traverse to the Int responsible for the count?
) // <> anotherReducer.lift(...) <> .identity

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

store.dispatch(.count(.increment))
store.dispatch(.count(.increment))
store.dispatch(.count(.decrement))
store.dispatch(.count(.increment))
store.dispatch(.count(.decrement))
store.dispatch(.count(.decrement))
store.dispatch(.count(.decrement))
store.dispatch(.count(.increment))

//: [Next](@next)
