public struct Reducer<StateType> {
    let reduce: (StateType, Action) -> StateType

    public init(_ reduce: @escaping (StateType, Action) -> StateType) {
        self.reduce = reduce
    }
}

extension Reducer: Monoid {
    public static var empty: Reducer<StateType> {
        return Reducer { state, _ in state }
    }

    public static func <> (lhs: Reducer<StateType>, rhs: Reducer<StateType>) -> Reducer<StateType> {
        return Reducer { state, action in
            return rhs.reduce(lhs.reduce(state, action), action)
        }
    }
}

extension Reducer {
    public func lift<Whole>(_ substatePath: WritableKeyPath<Whole, StateType>) -> Reducer<Whole> {
        return Reducer<Whole> { wholeState, action in
            var wholeState = wholeState
            let substate = wholeState[keyPath: substatePath]
            wholeState[keyPath: substatePath] = self.reduce(substate, action)
            return wholeState
        }
    }
}
