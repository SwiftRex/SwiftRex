/// A cancellation handle returned by an effect subscription or a state observation registration.
///
/// When the ``Store`` starts an ``Effect`` component or when ``StoreType/observe(willChange:didChange:)``
/// registers callbacks, a `SubscriptionToken` is returned. Call ``cancel()`` on it to stop the
/// work or remove the observer.
///
/// ## Why not `Cancellable`?
///
/// The name `SubscriptionToken` is chosen deliberately to avoid a name collision with Combine's
/// `Cancellable` protocol and the reactive-framework types with the same name. Bridge targets
/// wrap their framework-specific cancellation handles into this single, framework-agnostic type:
///
/// ```swift
/// // CombineRex — wraps an AnyCancellable
/// SubscriptionToken { anyCancellable.cancel() }
///
/// // RxSwiftRex — wraps a Disposable
/// SubscriptionToken { disposable.dispose() }
///
/// // Swift concurrency — wraps a Task
/// SubscriptionToken { task.cancel() }
///
/// // A no-op token (e.g., for effects that can't be cancelled)
/// SubscriptionToken.empty
/// ```
///
/// ## Lifetime management
///
/// Store the returned token in a property or collection and call ``cancel()`` when the
/// subscriber's lifetime ends (e.g., in `deinit` or on view disappear):
///
/// ```swift
/// var tokens: [SubscriptionToken] = []
///
/// func subscribe() {
///     tokens.append(
///         store.observe(didChange: { self.updateUI() })
///     )
/// }
///
/// deinit {
///     tokens.forEach { $0.cancel() }
/// }
/// ```
///
/// If you discard the token without cancelling, the subscription leaks — the observer or
/// effect keeps running for the lifetime of the ``Store``.
///
/// - Note: `cancel()` may be called from any thread. The ``Store`` and ``StoreBuffer``
///   implement observer removal via `Task { @MainActor }` to ensure thread safety.
public struct SubscriptionToken: Sendable {
    private let _cancel: @Sendable () -> Void

    /// Creates a `SubscriptionToken` backed by a cancellation closure.
    ///
    /// - Parameter cancel: A `@Sendable` closure invoked when ``cancel()`` is called.
    ///   May be called from any thread, any number of times (idempotency is the caller's
    ///   responsibility for the underlying resource).
    public init(_ cancel: @escaping @Sendable () -> Void) {
        _cancel = cancel
    }

    /// Cancels the associated subscription or observation.
    ///
    /// For effect subscriptions, this calls the ``SubscriptionToken`` returned from the
    /// ``Effect/Component/subscribe`` closure. For state observers registered via
    /// ``StoreType/observe(willChange:didChange:)``, this removes both callbacks.
    public func cancel() {
        _cancel()
    }

    /// A token that does nothing when cancelled.
    ///
    /// Use as a placeholder when an effect or subscription cannot be cancelled, or as a
    /// default return value when no real cancellation is needed:
    ///
    /// ```swift
    /// // Effect that completes immediately and cannot be cancelled
    /// subscribe: { send, complete in
    ///     send(action)
    ///     complete()
    ///     return .empty   // no cancellation needed
    /// }
    /// ```
    public static let empty = SubscriptionToken { }
}
