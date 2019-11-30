//: [Previous](@previous)

// Please start by selecting target Playgrounds and any iPhone from the device list
// Then build the target and run the playground

import Combine
import CombineRex
import PlaygroundSupport
import SwiftRex

PlaygroundPage.current.needsIndefiniteExecution = true

enum AppAction: Equatable {
    case event(CounterEvent)
    case action(CounterAction)

    enum CounterEvent: Equatable {
        case requestIncrease, requestDecrease
    }

    enum CounterAction: Equatable {
        case increase, decrease
    }

    var event: CounterEvent? {
        get {
            guard case let .event(value) = self else { return nil }
            return value
        }
        set {
            guard case .event = self, let newValue = newValue else { return }
            self = .event(newValue)
        }
    }

    var action: CounterAction? {
        get {
            guard case let .action(value) = self else { return nil }
            return value
        }
        set {
            guard case .action = self, let newValue = newValue else { return }
            self = .action(newValue)
        }
    }
}

struct AppState: Codable, Equatable {
    var currentNumber = 0
}

enum CounterService {
    static let middleware = CounterMiddleware()

    static let reducer = Reducer<AppAction.CounterAction, Int> { action, state in
        switch action {
        case .increase: return state + 1
        case .decrease: return state - 1
        }
    }

    class CounterMiddleware: Middleware {
        typealias InputActionType = AppAction.CounterEvent
        typealias OutputActionType = AppAction.CounterAction
        typealias StateType = Int

        var context: () -> MiddlewareContext<AppAction.CounterAction, Int> = { fatalError("Not set yet") }

        func handle(action: AppAction.CounterEvent, next: @escaping Next) {
            next()
            switch action {
            case .requestIncrease: context().dispatch(.increase)
            case .requestDecrease: context().dispatch(.decrease)
            }
        }
    }
}

final class Store: ReduxStoreBase<AppAction, AppState> {
    init() {
        super.init(
            subject: .combine(initialValue: AppState()),
            reducer:
                CounterService.reducer.lift(
                    action: \AppAction.action,
                    state: \AppState.currentNumber
                ),
            middleware:
                CounterService.middleware.lift(
                    actionZoomIn: { $0.event },
                    actionZoomOut: {
                        AppAction.action($0)
                    },
                    stateZoomIn: { $0.currentNumber }
                ),
            emitsValue: .whenDifferent
        )
    }
}

class ViewModel {
    private var subscription: AnyCancellable?
    private var storeProjection: StoreProjection<Input, Output>!

    enum Input {
        case tapIncrease
        case tapDecrease

        var tapIncrease: Void? {
            guard case .tapIncrease = self else { return nil }
            return ()
        }

        var tapDecrease: Void? {
            guard case .tapDecrease = self else { return nil }
            return ()
        }
    }

    struct Output: Codable, Equatable {
        let counterLabel: String
    }

    init(store: Store) {
        storeProjection = store.projection(
            action: { viewEvent in
                switch viewEvent {
                case .tapIncrease: return .event(.requestIncrease)
                case .tapDecrease: return .event(.requestDecrease)
                }
            },
            state: { global in
                global.map { state in
                    Output(counterLabel: "Formatted for View: \(state.currentNumber)")
                }.asPublisherType()
            }
        )

        subscription = storeProjection
            .statePublisher
            .map { String(data: try! JSONEncoder().encode($0), encoding: .utf8)! }
            .sink { print("New view state: \($0)") }
    }

    func receivedFromViewController(_ event: Input) {
        storeProjection.dispatch(event)
    }
}

let store = Store()
let viewModel = ViewModel(store: store)

viewModel.receivedFromViewController(.tapIncrease)
viewModel.receivedFromViewController(.tapIncrease)
viewModel.receivedFromViewController(.tapIncrease)
viewModel.receivedFromViewController(.tapDecrease)
viewModel.receivedFromViewController(.tapIncrease)
viewModel.receivedFromViewController(.tapDecrease)
viewModel.receivedFromViewController(.tapDecrease)

//: [Next](@next)
