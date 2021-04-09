//: [Previous](@previous)

import PlaygroundSwiftRexProxy
import CombineRex
import SwiftRex
import UIKit

/*
How to use:
- Open Playground/Playground.xcworkspace on Xcode (not the xcodeproj)
- Wait for SPM to resolve dependencies
- Select target PlaygroundSwiftRexProxy and any iOS simulator
- Build it
- Play the Playground page
*/

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

// MARK: - View world

// View state (everything we output to the user)
struct CounterViewState: Equatable {
    let formattedCount: String
    static func from(appState: AppState) -> CounterViewState {
        .init(formattedCount: "\(appState.count)")
    }
}

// View action (everything the user inputs to the app)
enum CounterViewAction {
    case tapPlus, tapMinus
    var asAppAction: AppAction? {
        switch self {
        case .tapPlus: return .count(.increment)
        case .tapMinus: return .count(.decrement)
        }
    }
}

// View model (a store projection that translates Store world into View world and vice-versa
let viewModel: StoreProjection<CounterViewAction, CounterViewState> =
    store.projection(action: \CounterViewAction.asAppAction,
                     state: CounterViewState.from(appState:))

// Optional: to work with SwiftUI, you can use that and set it as a @ObservedObject
// viewModel.asObservableViewModel(initialState: CounterViewState.init(formattedCount: ""))

let cancellable = viewModel.statePublisher.sink {
    print("Got new state: \($0)")
}

viewModel.dispatch(.tapPlus)
viewModel.dispatch(.tapPlus)
viewModel.dispatch(.tapMinus)
viewModel.dispatch(.tapPlus)
viewModel.dispatch(.tapMinus)
viewModel.dispatch(.tapMinus)
viewModel.dispatch(.tapMinus)
viewModel.dispatch(.tapPlus)

//: [Next](@next)
