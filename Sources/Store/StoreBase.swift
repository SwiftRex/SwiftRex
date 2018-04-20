import Foundation
import RxSwift

open class StoreBase<E>: Store {
    private let middleware: AnyMiddleware<E>
    private let reducer: Reducer<E>
    private let state: BehaviorSubject<E>
    private let dispatchEventQueue = DispatchQueue.main
    private let triggerActionQueue = DispatchQueue.main
    private let reduceQueue = DispatchQueue.main

    public init<M: Middleware>(initialState: E, reducer: Reducer<E>, middleware: M) where M.StateType == E {
        self.state = BehaviorSubject<E>(value: initialState)
        self.reducer = reducer
        self.middleware = AnyMiddleware(middleware)
        self.middleware.actionHandler = self
    }

    public convenience init(initialState: E, reducer: Reducer<E>) {
        self.init(initialState: initialState, reducer: reducer, middleware: BypassMiddleware())
    }

    open func dispatch(_ event: EventProtocol) {
        dispatchEventQueue.async {
            self.middlewarePipeline(for: event)
        }
    }

    open func trigger(_ action: ActionProtocol) {
        triggerActionQueue.async {
            self.middlewarePipeline(for: action)
        }
    }

    public func subscribe<O>(_ observer: O) -> Disposable where O: ObserverType, O.E == StateType {
        return state
            .observeOn(MainScheduler.instance)
            .subscribe(observer)
    }
}

extension StoreBase {
    private func middlewarePipeline(for event: EventProtocol) {
        let ignore: (EventProtocol, GetState<E>) -> Void = { _, _ in }
        middleware.handle(
            event: event,
            getState: { [unowned self] in try! self.state.value() },
            next: ignore)
    }

    private func middlewarePipeline(for action: ActionProtocol) {
        middleware.handle(
            action: action,
            getState: { [unowned self] in try! self.state.value() },
            next: { [weak self] action, _ in
                self?.reduceQueue.async {
                    self?.reduce(action: action)
                }
            })
    }

    private func reduce(action: ActionProtocol) {
        let oldState = try! state.value()
        let newState = reducer.reduce(oldState, action)
        state.onNext(newState)
    }
}
