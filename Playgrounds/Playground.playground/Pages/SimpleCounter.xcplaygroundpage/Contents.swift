import PlaygroundSupport
import SwiftRex

PlaygroundPage.current.needsIndefiniteExecution = true

// App state, shared among all modules of our app
struct GlobalState: Equatable, Codable {
    var currentNumber = 0
}

// For simplicity, this enum is both an Event and an Action
// DirectLineMiddleware transfers it directly to the reducers
enum CounterEvent: EventProtocol, ActionProtocol, Equatable {
    case increase, decrease
}

// Only one Action type to handle, no need for sub-reducers
let reducer = Reducer<GlobalState> { state, action in
    guard let counterEvent = action as? CounterEvent else { return state }

    var state = state
    switch counterEvent {
    case .increase: state.currentNumber += 1
    case .decrease: state.currentNumber -= 1
    }

    return state
}

// Store glues all pieces together
final class Store: StoreBase<GlobalState> {
    init() {
        super.init(initialState: GlobalState(), reducer: reducer, middleware: DirectLineMiddleware())
    }
}

let store = Store()
store
    .map { String(data: try! JSONEncoder().encode($0), encoding: .utf8)! }
    .subscribe(onNext: { print("New state: \($0)") })

store.dispatch(CounterEvent.increase)
store.dispatch(CounterEvent.increase)
store.dispatch(CounterEvent.increase)
store.dispatch(CounterEvent.decrease)
store.dispatch(CounterEvent.increase)
store.dispatch(CounterEvent.decrease)
store.dispatch(CounterEvent.decrease)
