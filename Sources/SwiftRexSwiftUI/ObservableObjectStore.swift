#if canImport(Combine)
import Combine
import SwiftRex

/// A `@MainActor` SwiftUI view model that wraps any ``StoreType`` and adds `ObservableObject`
/// conformance for use with `@StateObject` / `@ObservedObject` on iOS 15+.
///
/// ## Mutation notification
///
/// `objectWillChange` is sent **before** each mutation via the store's `willChange` callback,
/// so SwiftUI's animation system captures the correct pre-mutation snapshot. `state` is a
/// computed property that reads live from the underlying store — no local copy is maintained
/// and no data is duplicated.
///
/// ## Projection first
///
/// If you need to narrow the action or state type before handing it to SwiftUI, apply
/// ``StoreType/projection(action:state:)`` first, then wrap the result:
///
/// ```swift
/// @StateObject var vm = ObservableObjectStore(
///     appStore.projection(action: AppAction.counter, state: \.counterState)
/// )
/// ```
///
/// Or use the convenience factory ``StoreType/asObservableObject()``:
///
/// ```swift
/// @StateObject var vm = appStore
///     .projection(action: AppAction.counter, state: \.counterState)
///     .buffer()
///     .asObservableObject()
/// ```
///
/// ## iOS version guidance
///
/// | iOS | Recommended wrapper | Property wrapper |
/// | --- | --- | --- |
/// | 15+ | ``ObservableObjectStore`` | `@StateObject` / `@ObservedObject` |
/// | 17+ | ``ObservableStore`` | `@State` |
///
/// On iOS 17+ prefer ``ObservableStore`` — the `@Observable` macro tracks individual field
/// access, so only views that read a changed field re-render.
@MainActor
public final class ObservableObjectStore<Action: Sendable, State: Sendable>
    : ObservableObject, StoreType {
    public var state: State { store.state }

    private let store: any StoreType<Action, State>
    private var token: SubscriptionToken?

    public init(_ store: some StoreType<Action, State>) {
        self.store = store
        token = self.store.observe(
            willChange: { [weak self] in self?.objectWillChange.send() },
            didChange: {}
        )
    }

    public func dispatch(_ action: Action, source: ActionSource) {
        store.dispatch(action, source: source)
    }

    @discardableResult
    public func observe(
        willChange: @escaping @MainActor @Sendable () -> Void,
        didChange: @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken {
        store.observe(willChange: willChange, didChange: didChange)
    }
}

extension StoreType {
    /// Wraps this store in an ``ObservableObjectStore`` for use with `@StateObject` / `@ObservedObject`.
    ///
    /// Requires iOS 15+ (Combine). The returned wrapper fires `objectWillChange` before each
    /// mutation, keeping SwiftUI animation snapshots accurate.
    ///
    /// Apply ``StoreType/projection(action:state:)`` before calling this method if you need to
    /// narrow the action or state type:
    ///
    /// ```swift
    /// @StateObject var vm = appStore
    ///     .projection(action: AppAction.counter, state: \.counterState)
    ///     .buffer()
    ///     .asObservableObject()
    /// ```
    ///
    /// On iOS 17+ prefer ``@ViewModel`` for field-level `@Observable` tracking.
    ///
    /// - Returns: An ``ObservableObjectStore`` wrapping `self`.
    public func asObservableObject() -> ObservableObjectStore<Action, State> {
        ObservableObjectStore(self)
    }
}
#endif
