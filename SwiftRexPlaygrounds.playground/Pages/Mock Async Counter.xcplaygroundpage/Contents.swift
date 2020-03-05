//: [Previous](@previous)

// Please start by selecting target Playgrounds and any iPhone from the device list
// Then build the target and run the playground

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
    var countingState = CountingState()
    var lastMessage = AlertMessage(date: Date.distantPast, text: nil)
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
    case didTapIncrease
    case didTapDecrease
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

// SideEffectError is a struct that implements ActionProtocol and
// can be returned from a SideEffectMiddleware in case of error
/*******************************************************************************
 Counter Service
 *******************************************************************************
 This is our service class, that would fetch data from the web, or maybe execute
 a disk I/O operation. In our case we are simulating a web request that increases
 or decreases some number in the cloud.
 */
final class CounterService: SideEffectProducer {
    struct RequestError: Error, Equatable, CustomDebugStringConvertible {
        let reason: String

        var debugDescription: String {
            reason
        }
    }

    var event: CounterEvent

    init(event: CounterEvent) {
        self.event = event
    }

    // This is a cold observable, that means, subscribing it
    // causes a side effect, which could be a network call
    // or a disk operation for example.
    func execute(getState: @escaping () -> GlobalState) -> Observable<ActionProtocol> {
        switch (event, getState().countingState.requestState) {
        case (.didTapIncrease, .stopped):
            return .concat(
                // Immediately inform that the request has started
                .just(CounterAction.didStartRequest(.didTapIncrease)),
                // Simulate some slow operation that returns after around 0.5 second
                Observable<ActionProtocol>.just(CounterAction.successfullyIncreased)
                    .delay(0.5, scheduler: SerialDispatchQueueScheduler(qos: .background))
            )
        case (.didTapDecrease, .stopped):
            return .concat(
                // Immediately inform that the request has started
                .just(CounterAction.didStartRequest(.didTapIncrease)),
                // Simulate some slow operation that returns after around 0.5 second
                Observable<ActionProtocol>.just(CounterAction.successfullyDecreased)
                    .delay(0.5, scheduler: SerialDispatchQueueScheduler(qos: .background))
            )
        default:
            // Here we guard against triggering a request when other is currently happening.
            // In a real-life scenario we could instead cancel the pending request or simply ignore.
            return .error(RequestError(reason: "Another pending operation"))
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
    var subscriptionOwner = DisposeBag()

    func sideEffect(for event: EventProtocol) -> AnySideEffectProducer<GlobalState>? {
        (event as? CounterEvent)
            .map(CounterService.init)
            .map(AnySideEffectProducer.init)
    }
}

/*******************************************************************************
 Reducers
 *******************************************************************************
 Let's compose two reducers: one for handling `CounterAction` and the second
 for the `SideEffectError`.
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
    guard let sideEffectError = action as? SideEffectError else { return state }

    return AlertMessage(date: sideEffectError.date,
                        text: "Can't execute \(sideEffectError.originalEvent): \(sideEffectError.error)")
}

let composedReducer =
    counterReducer.lift(\GlobalState.countingState)
        <> alertReducer.lift(\GlobalState.lastMessage)

/*******************************************************************************
 Store
 *******************************************************************************
 Store glues all pieces together
 */
final class Store: StoreBase<GlobalState> {
    init() {
        super.init(initialState: GlobalState(),
                   reducer: composedReducer,
                   middleware: CounterMiddleware())
    }
}

let store = Store()

/*******************************************************************************
 ViewModel
 *******************************************************************************
 Struct that represents the mutable properties of a View
 */
struct CounterViewModel: CustomDebugStringConvertible {
    let emoji: String
    let title: String
    let details: String

    init(state: CountingState) {
        switch state.requestState {
        case .stopped:
            emoji = "✅"
            title = "Value"
            details = String(state.currentNumber)
        case .requestingToIncrease:
            emoji = "⏳"
            title = "Increasing"
            details = "\(state.currentNumber) => \(state.currentNumber + 1)"
        case .requestingToDecrease:
            emoji = "⏳"
            title = "Decreasing"
            details = "\(state.currentNumber) => \(state.currentNumber - 1)"
        }
    }

    var debugDescription: String {
        "\(emoji)\t| \(title): \(details)"
    }
}

/*******************************************************************************
 ViewController
 *******************************************************************************
 Two roles (input + output):
 1) Sends user events to the store
 2) Subscriber for the store notifications (state changes) and presents it
 */

let disposeBag = DisposeBag()
let buttonIncrease = PublishSubject<Void>()
let buttonDecrease = PublishSubject<Void>()

func viewDidLoad() {
    // Subscription to present the state
    store[\.countingState]
        .distinctUntilChanged()
        .map(CounterViewModel.init)
        .subscribe(onNext: update)
        .disposed(by: disposeBag)

    // Subscription to present errors on the screen
    store[\.lastMessage]
        .distinctUntilChanged(\.date)
        .map(\.text)
        .unwrap()
        .map { "❌\t| \($0)" }
        .subscribe(onNext: update)
        .disposed(by: disposeBag)

    // Bind UIButton `buttonIncrease` touchUpInside to CounterEvent.didTapIncrease
    buttonIncrease
        .mapTo(CounterEvent.didTapIncrease)
        .subscribe(onNext: store.dispatch)
        .disposed(by: disposeBag)

    // Bind UIButton `buttonDecrease` touchUpInside to CounterEvent.didTapDecrease
    buttonDecrease
        .mapTo(CounterEvent.didTapDecrease)
        .subscribe(onNext: store.dispatch)
        .disposed(by: disposeBag)
}

func update(_ value: CustomDebugStringConvertible) {
    print(value)
}

viewDidLoad()

//
//
/*******************************************************************************
 User interaction
 *******************************************************************************
 Let's simulate some button taps
 */
let taps = [
    buttonIncrease,
    buttonIncrease,
    buttonIncrease,
    buttonDecrease,
    buttonIncrease,
    buttonDecrease,
    buttonDecrease
]

// Interval between taps
// Setting to a number close to 0.5, which is the time needed to
// fullfil the request, may result in some alerts to the user
let interval = 0.55

taps
    .map(Observable<PublishSubject<Void>>.just)
    .map(delay(interval))
    .concat()
    .subscribe(onNext: { $0.onNext(()) })

/*
 Example of an expected result:
 ✅    | Value: 0
 ⏳    | Increasing: 0 => 1
 ✅    | Value: 1
 ⏳    | Increasing: 1 => 2
 ✅    | Value: 2
 ❌    | Can't execute didTapIncrease: Another pending operation
 ⏳    | Increasing: 2 => 3
 ✅    | Value: 1
 ⏳    | Increasing: 1 => 2
 ✅    | Value: 2
 ❌    | Can't execute didTapDecrease: Another pending operation
 ⏳    | Increasing: 2 => 3
 ✅    | Value: 1
 As we can see, two operations have failed because another request
 was in progress and the "user" tapped the increase or decrease
 button. In a real-world app we could simply bind the
 `state.countingState.isLoading` to the button, making it disabled,
 or perhaps cancel the current request and make another one.
 */

// Useful extensions
extension ObservableType {
    public func unwrap<T>() -> Observable<T> where E == T? {
        self.filter { $0 != nil }.map { $0! }
    }

    public subscript<T>(_ keyPath: KeyPath<E, T>) -> Observable<T> {
        self.map { $0[keyPath: keyPath] }
    }

    public func map<T>(_ keyPath: KeyPath<E, T>) -> Observable<T> {
        self.map { $0[keyPath: keyPath] }
    }

    public func mapTo<T>(_ value: T) -> Observable<T> {
        self.map { _ in value }
    }

    public func distinctUntilChanged<T>(_ keyPath: KeyPath<E, T>) -> Observable<E> where T: Equatable {
        self.distinctUntilChanged { $0[keyPath: keyPath] == $1[keyPath: keyPath] }
    }
}

extension Collection where Element: ObservableConvertibleType {
    func concat() -> Observable<Element.E> {
        Observable<Element.E>.concat(self.map { $0.asObservable() })
    }
}

func delay<T>(_ time: Double) -> (Observable<T>) -> Observable<T> { { observable in
        observable.asObservable().delay(RxTimeInterval(time), scheduler: MainScheduler.instance)
    }
}

//: [Next](@next)
