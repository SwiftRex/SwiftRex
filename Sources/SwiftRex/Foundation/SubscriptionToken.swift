/// A token returned by an effect subscription or state observation that can be used to stop it.
///
/// Named `SubscriptionToken` rather than `Cancellable` to avoid collision with Combine's
/// `Cancellable` protocol. Bridge targets wrap their framework-specific tokens:
/// ```swift
/// SubscriptionToken { anyCancellable.cancel() }   // CombineRex
/// SubscriptionToken { disposable.dispose() }       // RxSwiftRex
/// SubscriptionToken { task.cancel() }              // async/await
/// ```
public struct SubscriptionToken {
    private let _cancel: () -> Void

    public init(_ cancel: @escaping () -> Void) {
        _cancel = cancel
    }

    public func cancel() {
        _cancel()
    }

    public static let empty = SubscriptionToken { }
}
