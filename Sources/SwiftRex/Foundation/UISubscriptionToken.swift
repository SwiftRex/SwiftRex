// SPDX-License-Identifier: Apache-2.0

/// The cancellation handle of a main-actor subscription — what ``StateStream/observe(_:)`` returns.
///
/// It has the same shape as ``SubscriptionToken`` (call ``cancel()``, or release it — RAII, like
/// `AnyCancellable`), but lives on the main actor, where store observation happens. That lets releasing it
/// cancel **synchronously**: its `deinit` is isolated to the main actor, so when the last reference goes away
/// on the main actor (a view disappearing, a store being dropped) the observer is removed right there — no
/// hop, no stray callback after cancellation. Released from another thread, the runtime runs the `deinit` on
/// the main actor instead.
///
/// ```swift
/// let token = store.stateStream.observe { state in render(state) } // first call happens right here
/// token.cancel() // or just drop `token`
/// ```
///
/// Retain it for as long as you want values: discarding it cancels immediately.
@MainActor
public final class UISubscriptionToken {
    private var onCancel: (@MainActor () -> Void)?

    /// A token that runs `onCancel` once — on ``cancel()`` or when released, whichever comes first.
    public init(_ onCancel: @escaping @MainActor () -> Void) {
        self.onCancel = onCancel
    }

    /// Cancels the subscription. Idempotent: only the first call (or the release) does anything.
    public func cancel() {
        let cancel = onCancel
        onCancel = nil
        cancel?()
    }

    isolated deinit {
        onCancel?()
    }

    /// A token with nothing to cancel.
    public static var empty: UISubscriptionToken { UISubscriptionToken {} }
}
