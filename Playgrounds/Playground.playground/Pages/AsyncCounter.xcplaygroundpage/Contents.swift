import PlaygroundSupport
import RxSwift
import SwiftRex

PlaygroundPage.current.needsIndefiniteExecution = true

/*******************************************************************************
 App state
 *******************************************************************************

 Shared among all modules of our app
 */
struct GlobalState: Equatable {
    var countingState: CountingState = CountingState()
    var lastMessage: AlertMessage = AlertMessage(date: Date.distantPast, text: nil)
}

struct CountingState: Equatable {
    var currentNumber = 0
    var requestState: RequestState = .stopped
}

enum RequestState: Equatable {
    case stopped, requestingToIncrease, requestingToDecrease
}

struct AlertMessage: Equatable {
    let date: Date
    let text: String?
}

/*******************************************************************************
 Events
 *******************************************************************************

 Events that users can send
 */
enum CounterEvent: EventProtocol, Equatable {
    case didTapIncrease, didTapDecrease
}

/*******************************************************************************
 Actions
 *******************************************************************************

 Resulting actions for each event sent by the user. Those are created by the
 middlewares, sometimes due to an event, sometimes due to a web response
 */
enum CounterAction: ActionProtocol, Equatable {
    case successfullyIncreased
    case successfullyDecreased
    case didStartRequest(CounterEvent)
}

enum AlertAction: ActionProtocol, Equatable {
    case error(Date, String)
}

/*******************************************************************************
 Counter Service
 *******************************************************************************

 This is our service class, that would fetch data from the web, or maybe execute
 a disk I/O operation. In our case we are simulating a web request that increases
 or decreases some number in the cloud.
 */
final class CounterService: SideEffectProducer {
    var event: CounterEvent

    init(event: CounterEvent) {
        self.event = event
    }

    func execute(getState: @escaping () -> GlobalState) -> Observable<ActionProtocol> {
        switch event {
        case .didTapIncrease:
            guard case .stopped = getState().countingState.requestState else {
                return .just(AlertAction.error(Date(), "Can't increase: another pending operation"))
            }
            return increase().map { $0 as ActionProtocol }
        case .didTapDecrease:
            guard case .stopped = getState().countingState.requestState else {
                return .just(AlertAction.error(Date(), "Can't decrease: another pending operation"))
            }
            return decrease().map { $0 as ActionProtocol }
        }
    }

    func increase() -> Observable<CounterAction> {
        return Observable.create { observer in
            // This is a cold observable, that means, subscribing it
            // causes a side effect, which could be a network call
            // or a disk operation for example.
            observer.onNext(CounterAction.didStartRequest(.didTapIncrease))
            let cancel = Disposables.create { }

            DispatchQueue
                .global()
                .asyncAfter(deadline: .now() + 0.5) {
                    guard !cancel.isDisposed else { return }
                    observer.onNext(CounterAction.successfullyIncreased)
                    // Done with this side effect operation!
                    // Let's complete it and allow it to be disposed
                    observer.onCompleted()
            }

            return cancel
        }
    }

    func decrease() -> Observable<CounterAction> {
        return Observable.create { observer in
            // This is a cold observable, that means, subscribing it
            // causes a side effect, which could be a network call
            // or a disk operation for example.
            observer.onNext(CounterAction.didStartRequest(.didTapDecrease))
            let cancel = Disposables.create { }

            DispatchQueue
                .global()
                .asyncAfter(deadline: .now() + 0.5) {
                    guard !cancel.isDisposed else { return }
                    observer.onNext(CounterAction.successfullyDecreased)
                    // Done with this side effect operation!
                    // Let's complete it and allow it to be disposed
                    observer.onCompleted()
            }

            return cancel
        }
    }
}

/*******************************************************************************
 Counter Middleware
 *******************************************************************************

 Maps the event of type `CounterEvent` to the proper service, in this case
 `CounterService`.
 */
final class CounterMiddleware: SideEffectMiddleware {
    typealias StateType = GlobalState
    var actionHandler: ActionHandler?
    var allowEventToPropagate = false
    var disposeBag = DisposeBag()

    func sideEffect(for event: EventProtocol) -> AnySideEffectProducer<GlobalState>? {
        return (event as? CounterEvent)
            .map(CounterService.init)
            .map(AnySideEffectProducer.init)
    }
}

/*******************************************************************************
 Reducers
 *******************************************************************************

 Let's combine two reducers: one for handling `CounterAction` and the second
 for the `AlertAction`.
 */
let counterReducer = Reducer<CountingState> { state, action in
    guard let counterAction = action as? CounterAction else { return state }

    var state = state
    switch counterAction {
    case .successfullyIncreased:
        state.currentNumber += 1
        state.requestState = .stopped
    case .successfullyDecreased:
        state.currentNumber -= 1
        state.requestState = .stopped
    case .didStartRequest(let event):
        switch event {
        case .didTapIncrease:
            state.requestState = .requestingToIncrease
        case .didTapDecrease:
            state.requestState = .requestingToDecrease
        }
    }

    return state
}

let alertReducer = Reducer<AlertMessage> { state, action in
    guard let alertAction = action as? AlertAction else { return state }

    switch alertAction {
    case .error(let date, let text):
        return AlertMessage(date: date, text: text)
    }
}

/*******************************************************************************
 Store
 *******************************************************************************

 Store glues all pieces together
 */
final class Store: StoreBase<GlobalState> {
    init() {
        super.init(initialState: GlobalState(),
                   reducer: counterReducer.lift(\GlobalState.countingState)
                    <> alertReducer.lift(\GlobalState.lastMessage),
                   middleware: CounterMiddleware())
    }
}

let store = Store()


/*******************************************************************************
 ViewController
 *******************************************************************************

 Two roles (input + output):
 1) Sends user events to the store
 2) Subscriber for the store notifications (whenever state changes) and converts
    to user interface
 */

let disposeBag = DisposeBag()

// Subscription to present the state
store
    .map { $0.countingState }
    .distinctUntilChanged()
    .subscribe(onNext: {
        switch $0.requestState {
        case .stopped:
            print("✅\t| Value: \($0.currentNumber)")
        case .requestingToIncrease:
            print("⏳\t| Increasing: \($0.currentNumber) => \($0.currentNumber + 1)")
        case .requestingToDecrease:
            print("⏳\t| Decreasing: \($0.currentNumber) => \($0.currentNumber - 1)")
        }
    }).disposed(by: disposeBag)

// Subscription to present errors on the screen
store
    .map { $0.lastMessage }
    .distinctUntilChanged { $0.date }
    .filter { $0.text != nil }
    .map { $0.text! }
    .subscribe(onNext: { message in
        print("❌\t| \(message)")
    }).disposed(by: disposeBag)


// Let's simulate some button taps
let events = [
    CounterEvent.didTapIncrease,
    CounterEvent.didTapIncrease,
    CounterEvent.didTapIncrease,
    CounterEvent.didTapDecrease,
    CounterEvent.didTapIncrease,
    CounterEvent.didTapDecrease,
    CounterEvent.didTapDecrease]

// Interval between taps
// Setting to 0.55, which is very close to the time needed to
// fullfil the request, may result in some alerts to the user
let interval = 0.55

events
    .enumerated()
    .map { pair in
        (time: DispatchTime.now() + Double(pair.0) * interval,
         work: { store.dispatch(pair.1) }) }
    .forEach {
        DispatchQueue.main.asyncAfter(deadline: $0.time, execute: $0.work)
    }

/*
 Example of an expected result:

 ✅    | Value: 0
 ⏳    | Increasing: 0 => 1
 ✅    | Value: 1
 ❌    | Can't increase: another pending operation
 ⏳    | Increasing: 1 => 2
 ✅    | Value: 2
 ❌    | Can't decrease: another pending operation
 ⏳    | Increasing: 2 => 3
 ❌    | Can't decrease: another pending operation
 ✅    | Value: 3
 ⏳    | Decreasing: 3 => 2
 ✅    | Value: 2

 As we can see, two operations have failed because another request
 was in progress and the "user" tapped the increase or decrease
 button. In a real-world app we could simply bind the
 `state.countingState.isLoading` to the button, making it disabled,
 or perhaps cancel the current request and make another one.
*/
