import CombineX
import CXFoundation
import Foundation

struct BlockPublisher<OutputType, FailureType: Error>: CombineX.Publisher {
    typealias Output = OutputType
    typealias Failure = FailureType

    private let onSubscribe: (CombineX.AnySubscriber<OutputType, FailureType>) -> Void
    init(_ onSubscribe: @escaping (CombineX.AnySubscriber<OutputType, FailureType>) -> Void) {
        self.onSubscribe = onSubscribe
    }

    func receive<S>(subscriber: S) where S: CombineX.Subscriber, Failure == S.Failure,
        Output == S.Input {
            onSubscribe(AnySubscriber(subscriber))
    }
}
