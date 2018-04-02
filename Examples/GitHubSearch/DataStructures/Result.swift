public enum Result<T> {
    case success(T)
    case failure(Error)
}

extension Result {
    public func possibleValue() -> T? {
        switch self {
        case .success(let value): return value
        case .failure: return nil
        }
    }
}

// MARK: - Functor, Monad
extension Result {
    @_inlineable
    public func map<B>(_ transform: (T) throws -> B) rethrows -> Result<B> {
        switch self {
        case .success(let valueT): return .success(try transform(valueT))
        case .failure(let error): return .failure(error)
        }
    }

    @_inlineable
    public func map<B>(_ transformValue: (T) throws -> B, _ transformError: (Error) throws -> B) rethrows -> B {
        switch self {
        case .success(let valueT): return try transformValue(valueT)
        case .failure(let error): return try transformError(error)
        }
    }

    @_inlineable
    public func flatMap<B>(_ transform: (T) throws -> Result<B>) rethrows -> Result<B> {
        switch self {
        case .success(let valueT): return try transform(valueT)
        case .failure(let error): return .failure(error)
        }
    }
}

// MARK: - Equatable
extension Result: Equatable where T: Equatable { }

@_inlineable
public func == <T>(lhs: Result<T>, rhs: Result<T>) -> Bool where T: Equatable {
    switch (lhs, rhs) {
    case let (.success(lhs), .success(rhs)):
        return lhs == rhs
    case let (.failure(lhs), .failure(rhs)):
        return lhs.localizedDescription == rhs.localizedDescription
    default:
        return false
    }
}

// MARK: - Coalescing operator
infix operator ???: NilCoalescingPrecedence

@_transparent
public func ??? <T>(result: Result<T>, defaultValue: @autoclosure () throws -> T)
    rethrows -> T {
        switch result {
        case .success(let value):
            return value
        case .failure:
            return try defaultValue()
        }
}

@_transparent
public func ??? <T>(result: Result<T>, defaultValue: @autoclosure () throws -> Result<T>)
    rethrows -> Result<T> {
        switch result {
        case .success(let value):
            return .success(value)
        case .failure:
            return try defaultValue()
        }
}

@_transparent
public func ??? <T>(result: Result<T>, defaultValue: @autoclosure () throws -> T?)
    rethrows -> T? {
        switch result {
        case .success(let value):
            return value
        case .failure:
            return try defaultValue()
        }
}

public struct EncodedError: Error, Codable {
    let message: String
}

extension Result {
    enum CodingKeys: CodingKey {
        case success
        case failure
    }
}

extension Result: Encodable where T: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .success(let value):
            try container.encode(value, forKey: .success)
        case .failure(let error):
            try container.encode(EncodedError(message: error.localizedDescription), forKey: .failure)
        }
    }
}

extension Result: Decodable where T: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            let successValue = try container.decode(T.self, forKey: .success)
            self = .success(successValue)
        } catch {
            let error = try container.decode(EncodedError.self, forKey: .failure)
            self = .failure(error)
        }
    }
}
