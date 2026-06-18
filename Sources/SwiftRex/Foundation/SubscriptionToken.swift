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
/// // SwiftRexCombine — wraps an AnyCancellable
/// SubscriptionToken { anyCancellable.cancel() }
///
/// // SwiftRexRxSwift — wraps a Disposable
/// SubscriptionToken { disposable.dispose() }
///
/// // SwiftRexSwiftConcurrency — wraps a Task
/// SubscriptionToken { task.cancel() }
///
/// // A no-op token (e.g., for effects that can't be cancelled)
/// SubscriptionToken.empty
/// ```
///
/// ## Lifetime management — RAII, like `AnyCancellable`
///
/// `SubscriptionToken` is a **reference type** whose `deinit` calls ``cancel()``. Releasing the
/// last reference therefore cancels automatically — there is no "leak on discard". Two
/// consequences follow:
///
/// - **Effect subscriptions** are owned by the ``Store``'s registry. Replacing the token under a
///   key (`.replacing`, `.debounce`, `.throttle`) releases the previous one and cancels its
///   effect; tearing down the Store releases the whole registry and cancels everything in flight.
/// - **Observations** are owned by *you*. Retain the token for as long as you want the callbacks
///   to fire — store it in a property or a `Set`/array — exactly like Combine's `AnyCancellable`:
///
/// ```swift
/// var tokens: [SubscriptionToken] = []
///
/// func subscribe() {
///     tokens.append(store.observe(didChange: { self.updateUI() }))
/// }
/// // Dropping `tokens` (or this object) cancels the observation automatically.
/// ```
///
/// Discarding an observation token without retaining it cancels the observation **immediately** —
/// the callbacks never fire. This is why ``StoreType/observe(willChange:didChange:)`` is not
/// `@discardableResult`.
///
/// - Note: `cancel()` may be called from any thread, and is also called by `deinit`, so it may
///   run more than once — keeping the underlying cancellation idempotent is the resource's
///   responsibility (`Task.cancel()`, `AnyCancellable.cancel()`, `Disposable.dispose()` all are).
///   The ``Store`` and ``StoreBuffer`` remove observers via `Task { @MainActor }` for thread safety.
public final class SubscriptionToken: Sendable {
    private let _cancel: @Sendable () -> Void

    /// Creates a `SubscriptionToken` backed by a cancellation closure.
    ///
    /// - Parameter cancel: A `@Sendable` closure invoked when ``cancel()`` is called or when the
    ///   token is released. May be called from any thread, any number of times (idempotency is
    ///   the caller's responsibility for the underlying resource).
    public init(_ cancel: @escaping @Sendable () -> Void) {
        _cancel = cancel
    }

    /// Cancels the associated subscription or observation.
    ///
    /// For effect subscriptions, this calls the ``SubscriptionToken`` returned from the
    /// ``Effect/Component/subscribe`` closure. For state observers registered via
    /// ``StoreType/observe(willChange:didChange:)``, this removes both callbacks. Also invoked
    /// automatically by `deinit` when the last reference is released.
    public func cancel() {
        _cancel()
    }

    /// Cancels automatically when the last reference is released (RAII / `AnyCancellable` style).
    deinit {
        _cancel()
    }

    /// A token that does nothing when cancelled.
    ///
    /// Use as a placeholder when an effect or subscription cannot be cancelled, or as a
    /// default return value when no real cancellation is needed. It is a single shared instance,
    /// so it is never deallocated and its no-op `deinit` never matters:
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
