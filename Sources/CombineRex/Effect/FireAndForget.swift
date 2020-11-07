#if canImport(Combine)
import Combine
import Foundation

/// Fire And Forget is a publisher for when you don't care about the output of certain async operation. It's important to notice that this operation
/// can't fail. If you want to also ignore the failure, then you can catchErrors and return nil in the proper init.
/// It may complete successfully when task is done.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct FireAndForget<IgnoringOutput>: Publisher {
    /// Output type we are ignoring. It matches the FireAndForget generic parameter, so we can ignore anything we want.
    public typealias Output = IgnoringOutput
    /// We're only able to ignore the output, not the failure, so it's important that this publisher never fails. To ignore also the failure path
    /// please use the init with catchErrors parameter and return nil from it.
    public typealias Failure = Never

    private let innerPublisher: AnyPublisher<IgnoringOutput, Never>

    /// Init a FireAndForget publisher by providing a closure with the operation to execute and ignore the output.
    /// - Parameter operation: any operation you want to run async and ignore the result
    public init(_ operation: @escaping () -> Void) {
        self.init(Empty<IgnoringOutput, Never>().handleEvents(receiveSubscription: { _ in operation() }))
    }

    /// Init a FireAndForget publisher by providing an upstream that never fails so we can simply ignore its output
    /// - Parameter upstream: any publisher that never fails
    public init<P: Publisher>(_ upstream: P) where P.Failure == Never {
        innerPublisher = upstream
            .ignoreOutput()
            .map { _ -> IgnoringOutput in }
            .eraseToAnyPublisher()
    }

    /// Init a FireAndForget publisher by providing an upstream that could fail, as well as a catchErrors function to ensure that FireAndForget can't
    /// itself fail. You can safely return nil from catchErrors. Otherwise outputs sent from catch errors will NOT be ignored, only those from the
    /// happy path.
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

    /// Attaches the specified subscriber to this publisher.
    ///
    /// Implementations of ``Publisher`` must implement this method.
    ///
    /// - Parameter subscriber: The subscriber to attach to this ``Publisher``, after which it can receive values.
    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        innerPublisher.receive(subscriber: subscriber)
    }
}
#endif
