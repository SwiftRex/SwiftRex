import PlaygroundSupport
import RxSwift
import SwiftRex

PlaygroundPage.current.needsIndefiniteExecution = true

// App state, shared among all modules of our app
struct GlobalState: Equatable, Codable {
    var currentNumber = 0
    var isLoading = false
}

enum CounterEvent: EventProtocol, Equatable {
    case didTapIncrease, didTapDecrease
}

enum CounterAction: ActionProtocol, Equatable {
    case successfullyIncreased, successfullyDecreased, didStartRequest
}

final class CounterService: SideEffectProducer {
    var event: CounterEvent

    init(event: CounterEvent) {
        self.event = event
    }

    func execute(getState: @escaping () -> GlobalState) -> Observable<ActionProtocol> {
        guard !getState().isLoading else { return .empty() }

        switch event {
        case .didTapIncrease: return increase().map { $0 as ActionProtocol }
        case .didTapDecrease: return decrease().map { $0 as ActionProtocol }
        }
    }

    func increase() -> Observable<CounterAction> {
        return Observable.create { observer in
            // This is a cold observable, that means, subscribing it
            // causes a side effect, which could be a network call
            // or a disk operation for example.
            observer.onNext(CounterAction.didStartRequest)
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
            observer.onNext(CounterAction.didStartRequest)
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

// Only one Action type to handle, no need for sub-reducers
let reducer = Reducer<GlobalState> { state, action in
    guard let counterAction = action as? CounterAction else { return state }

    var state = state
    switch counterAction {
    case .successfullyIncreased:
        state.currentNumber += 1
        state.isLoading = false
    case .successfullyDecreased:
        state.currentNumber -= 1
        state.isLoading = false
    case .didStartRequest:
        state.isLoading = true
    }

    return state
}

// Store glues all pieces together
final class Store: StoreBase<GlobalState> {
    init() {
        super.init(initialState: GlobalState(), reducer: reducer, middleware: CounterMiddleware())
    }
}

let store = Store()
let disposable = store
    .distinctUntilChanged()
    .subscribe(onNext: {
        let statusIcon = $0.isLoading ? "⏳" : "✅"
        print("\(statusIcon) | Value: \($0.currentNumber)")
    })

let events = [
    CounterEvent.didTapIncrease,
    CounterEvent.didTapIncrease,
    CounterEvent.didTapIncrease,
    CounterEvent.didTapDecrease,
    CounterEvent.didTapIncrease,
    CounterEvent.didTapDecrease,
    CounterEvent.didTapDecrease]

let interval = 0.6

events
    .enumerated()
    .map { pair in
        (time: DispatchTime.now() + Double(pair.0) * interval,
         work: { store.dispatch(pair.1) }) }
    .forEach {
        DispatchQueue.main.asyncAfter(deadline: $0.time, execute: $0.work)
    }
