enum AsyncResult<T> {
    case notLoaded
    case loading(task: Cancelable, lastResult: Result<T>?)
    case loaded(Result<T>)
}

extension AsyncResult {
    func possibleResult() -> Result<T>? {
        switch self {
        case .notLoaded: return nil
        case .loading(_, let result): return result
        case .loaded(let result): return result
        }
    }

    func possibleValue() -> T? {
        return possibleResult().flatMap { $0.possibleValue() }
    }

    func possibleTask() -> Cancelable? {
        switch self {
        case .loading(let task, _): return task
        default: return nil
        }
    }
}

extension AsyncResult: Equatable where T: Equatable {
    static func == (lhs: AsyncResult<T>, rhs: AsyncResult<T>) -> Bool {
        switch (lhs, rhs) {
        case (.notLoaded, .notLoaded):
            return true
        case (.loading(_, let lhs), (.loading(_, let rhs))):
            return lhs == rhs
        case (.loaded(let lhs), (.loaded(let rhs))):
            return lhs == rhs
        default:
            return false
        }
    }
}
