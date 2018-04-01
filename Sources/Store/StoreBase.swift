import RxSwift

open class StoreBase<E>: Store {
    private let middleware: AnyMiddleware<E>
    private let reducer: AnyReducer<E>
    private let state: BehaviorSubject<E>

    public init<R: Reducer, M: Middleware>(
        initialState: E,
        reducer: R,
        middleware: M) where R.StateType == E, M.StateType == E {

        self.state = BehaviorSubject<E>(value: initialState)
        self.reducer = AnyReducer(reducer)
        self.middleware = AnyMiddleware(middleware)
        self.middleware.actionHandler = self
    }

    public convenience init<R: Reducer>(
        initialState: E,
        reducer: R) where R.StateType == E {

        self.init(initialState: initialState, reducer: reducer, middleware: BypassMiddleware())
    }

    open func dispatch(_ event: Event) {
        let ignore: (Event, GetState<E>) -> Void = { _, _ in }
        middleware.handle(
            event: event,
            getState: { [unowned self] in try! self.state.value() },
            next: ignore)
    }

    open func trigger(_ action: Action) {
        middleware.handle(
            action: action,
            getState: { [unowned self] in try! self.state.value() },
            next: { action, _ in
                let oldState = try! self.state.value()
                let newState = self.reducer.reduce(oldState, action: action)
                self.state.onNext(newState)
        })
    }

    public func subscribe<O>(_ observer: O) -> Disposable where O: ObserverType, O.E == StateType {
        return state
            .observeOn(MainScheduler.instance)
            .subscribe(observer)
    }
}
