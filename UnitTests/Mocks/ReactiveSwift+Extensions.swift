import struct ReactiveSwift.SignalProducer
import class ReactiveSwift.ScopedDisposable
import class ReactiveSwift.CompositeDisposable
import SwiftRex

func observable<T>(of type: T.Type, error: Error) -> SignalProducer<T, Error> {
    return SignalProducer<T, Error> { observer, _ in
        observer.send(error: error)
    }
}

func observable<T>(of values: T...) -> SignalProducer<T, Error> {
    return SignalProducer<T, Error> { observer, _ in
        values.forEach(observer.send)
        observer.sendCompleted()
    }
}

extension SignalProducer {
    func toBlocking() -> SignalProducer<[Value], Error> {
        return collect()
    }
}

extension SignalProducer where Value: Collection {
    func toArray() throws -> [Value.Element] {
        switch single() {
        case let .some(.success(collection)): return Array(collection)
        case let .some(.failure(error)): throw error
        case .none: return []
        }
    }
}

extension ScopedDisposable where Inner == CompositeDisposable {
    static func new() -> SubscriptionOwner {
        return .init(.init())
    }
}
