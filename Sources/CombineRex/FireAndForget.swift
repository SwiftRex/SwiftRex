#if canImport(Combine)
import Combine
import Foundation

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct FireAndForget<IgnoringOutput>: Publisher {
    public typealias Output = IgnoringOutput
    public typealias Failure = Never

    private let innerPublisher: AnyPublisher<IgnoringOutput, Never>

    public init(_ operation: @escaping () -> Void) {
        self.init(Empty<IgnoringOutput, Never>().handleEvents(receiveSubscription: { _ in operation() }))
    }

    public init<P: Publisher>(_ upstream: P) where P.Failure == Never {
        innerPublisher = upstream
            .ignoreOutput()
            .map { _ -> IgnoringOutput in }
            .eraseToAnyPublisher()
    }

    public init<P: Publisher>(_ upstream: P, catchErrors: @escaping (P.Failure) -> IgnoringOutput?) {
        innerPublisher = upstream
            .ignoreOutput()
            .map { _ -> IgnoringOutput in }
            .catch { error -> Just<IgnoringOutput?> in
                Just(catchErrors(error))
            }
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }

    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        innerPublisher.receive(subscriber: subscriber)
    }
}
#endif
