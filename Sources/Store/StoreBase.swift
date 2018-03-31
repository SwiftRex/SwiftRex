open class StoreBase<GlobalState>: Store {
    private let mainReducer: ReducerFunction<GlobalState>
    private var currentState: GlobalState {
        didSet {
            // notify
        }
    }

    public let middlewares: MiddlewareContainer<GlobalState> = .init()

    public init(initialState: GlobalState, mainReducer: @escaping ReducerFunction<GlobalState>) {
        self.currentState = initialState
        self.mainReducer = mainReducer
    }

    public convenience init<M: Middleware>(
        initialState: GlobalState,
        reducers: [ReducerFunction<GlobalState>],
        middlewares: [M]) where M.StateType == GlobalState {

        self.init(initialState: initialState) { state, action in
            reducers.reduce(state) { $1($0, action) }
        }

        middlewares.forEach(self.middlewares.append)
    }

    open func dispatch(_ event: Event) {
        let ignore: (Event, () -> GlobalState) -> Void = { _, _ in }
        middlewares.handle(
            event: event,
            getState: { [unowned self] in self.currentState },
            next: ignore)
    }

    open func trigger(_ action: Action) {
        middlewares.handle(
            action: action,
            getState: { [unowned self] in self.currentState },
            next: { action, _ in self.currentState = self.mainReducer(self.currentState, action) })
    }

    open func subscribe() -> Observable<GlobalState> {
        return Observable()
    }
}
