import Foundation
import ReactiveSwift

/// Fire And Forget is a SignalProducer for when you don't care about the output of certain async operation. It's important to notice that this
/// operation can't fail. If you want to also ignore the failure, then you can catchErrors and return nil in the proper init.
/// It may complete successfully when task is done.
public struct FireAndForget<IgnoringOutput>: SignalProducerProtocol {
    public typealias Value = IgnoringOutput
    public typealias Error = Never

    public let producer: SignalProducer<IgnoringOutput, Never>

    /// Init a FireAndForget signal producer by providing a closure with the operation to execute and ignore the output.
    /// - Parameter operation: any operation you want to run async and ignore the result
    public init(_ operation: @escaping () -> Void) {
        self.init(SignalProducer<Void, Never>.empty.on(started: { operation() }))
    }

    /// Init a FireAndForget signal producer by providing an upstream that never fails so we can simply ignore its output
    /// - Parameter upstream: any signal producer that never fails
    public init<S: SignalProducerProtocol>(_ upstream: S) where S.Error == Never {
        producer = upstream
            .producer
            .filter { _ in false }
            .map { _ -> IgnoringOutput in fatalError("SignalProducer is filtering all events, so map should have never been called") }
    }

    /// Init a FireAndForget signal producer by providing an upstream that could fail, as well as a catchErrors function to ensure that FireAndForget
    /// can't itself fail. You can safely return nil from catchErrors. Otherwise outputs sent from catch errors will NOT be ignored, only those from
    /// the happy path.
    public init<S: SignalProducerProtocol>(_ upstream: S, catchErrors: @escaping (S.Error) -> IgnoringOutput?) {
        producer = upstream
            .producer
            .filter { _ in false }
            .map { _ -> IgnoringOutput in fatalError("SignalProducer is filtering all events, so map should have never been called") }
            .flatMapError { error -> SignalProducer<IgnoringOutput?, Never> in
                .init(value: catchErrors(error))
            }
            .compactMap { $0 }
    }
}
