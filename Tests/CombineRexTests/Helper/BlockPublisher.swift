#if canImport(Combine)
import Combine
import Foundation

struct BlockPublisher<OutputType, FailureType: Error>: Publisher {
    typealias Output = OutputType
    typealias Failure = FailureType

    private let onSubscribe: (AnySubscriber<OutputType, FailureType>) -> Void
    init(_ onSubscribe: @escaping (AnySubscriber<OutputType, FailureType>) -> Void) {
        self.onSubscribe = onSubscribe
    }

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure,
        Output == S.Input {
            onSubscribe(AnySubscriber(subscriber))
    }
}
#endif
