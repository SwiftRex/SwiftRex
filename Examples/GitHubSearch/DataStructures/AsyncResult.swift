public enum AsyncResult<T> {
    case notLoaded
    case loading(task: Cancelable, lastResult: Result<T>?)
    case loaded(Result<T>)
}

extension AsyncResult {
    public func possibleResult() -> Result<T>? {
        switch self {
        case .notLoaded: return nil
        case .loading(_, let result): return result
        case .loaded(let result): return result
        }
    }

    public func possibleValue() -> T? {
        return possibleResult().flatMap { $0.possibleValue() }
    }

    public func possibleTask() -> Cancelable? {
        switch self {
        case .loading(let task, _): return task
        default: return nil
        }
    }
}

extension AsyncResult: Equatable where T: Equatable {
    public static func == (lhs: AsyncResult<T>, rhs: AsyncResult<T>) -> Bool {
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

extension AsyncResult {
    enum CodingKeys: CodingKey {
        case notLoaded
        case loading
        case loaded
    }
}

extension AsyncResult: Encodable where T: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .notLoaded:
            try container.encode(0, forKey: .notLoaded)
        case .loading(_, let value):
            try container.encode(value, forKey: .loading)
        case .loaded(let value):
            try container.encode(value, forKey: .loaded)
        }
    }
}
