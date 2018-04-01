public final class ComposedReducer<GlobalState>: Reducer {
    private(set) var reducers: [AnyReducer<GlobalState>] = []

    public init() { }

    public func append<R: Reducer>(reducer: R) where R.StateType == GlobalState {
        reducers.append((reducer as? AnyReducer) ?? AnyReducer(reducer))
    }

    public func reduce(_ currentState: GlobalState, action: Action) -> GlobalState {
        return reducers.reduce(currentState) { $1.reduce($0, action: action) }
    }
}

public func >>> <R1: Reducer, R2: Reducer> (lhs: R1, rhs: R2) -> ComposedReducer<R1.StateType> where R1.StateType == R2.StateType {

    let container = lhs as? ComposedReducer<R1.StateType> ?? {
        let newContainer: ComposedReducer<R1.StateType> = .init()
        newContainer.append(reducer: lhs)
        return newContainer
    }()

    if let rContainer = rhs as? ComposedReducer<R2.StateType> {
        rContainer.reducers.forEach(container.append)
    } else {
        container.append(reducer: rhs)
    }

    return container
}
