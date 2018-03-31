import RxSwift

open class StoreBase<GlobalState>: Store {
    public typealias E = GlobalState

    private let mainReducer: ReducerFunction<GlobalState>
    private let state: BehaviorSubject<GlobalState>

    public let middlewares: MiddlewareContainer<GlobalState> = .init()

    public init(initialState: GlobalState, mainReducer: @escaping ReducerFunction<GlobalState>) {
        self.state = BehaviorSubject<GlobalState>(value: initialState)
        self.mainReducer = mainReducer
        self.middlewares.actionHandler = self
    }

    public convenience init<M: Middleware>(
        initialState: GlobalState,
        reducers: [ReducerFunction<GlobalState>],
        middlewares: [M] = []) where M.StateType == GlobalState {

        self.init(initialState: initialState) { state, action in
            reducers.reduce(state) { $1($0, action) }
        }

        middlewares.forEach(self.middlewares.append)
    }

    open func dispatch(_ event: Event) {
        let ignore: (Event, GetState<GlobalState>) -> Void = { _, _ in }
        middlewares.handle(
            event: event,
            getState: { [unowned self] in try! self.state.value() },
            next: ignore)
    }

    open func trigger(_ action: Action) {
        middlewares.handle(
            action: action,
            getState: { [unowned self] in try! self.state.value() },
            next: { action, _ in
                let oldState = try! self.state.value()
                let newState = self.mainReducer(oldState, action)
                self.state.onNext(newState)
        })
    }

    public func subscribe<O>(_ observer: O) -> Disposable where O: ObserverType, O.E == StateType {
        return state.subscribe(observer)
    }
}
