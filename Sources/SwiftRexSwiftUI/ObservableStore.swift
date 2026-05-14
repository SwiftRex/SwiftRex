#if canImport(Observation)
import Observation
import SwiftRex

/// A `@MainActor` SwiftUI view model that wraps any ``StoreType`` and adds `@Observable`
/// conformance for use with `@State` on iOS 17+.
///
/// ## Fine-grained observation
///
/// Unlike `ObservableObject` (which invalidates all views subscribed to the object),
/// `@Observable`'s registrar tracks **individual property access**. Only the views that
/// actually read a field that changed are invalidated — unrelated views stay in the render tree
/// untouched.
///
/// `state` is a **stored** property updated after every mutation via the store's `didChange`
/// callback. The `@Observable` macro synthesises `_$observationRegistrar` tracking around it.
///
/// ## Projection first
///
/// Apply ``StoreType/projection(action:state:)`` before wrapping if you need a narrower
/// action or state type:
///
/// ```swift
/// @State var vm = ObservableStore(
///     appStore.projection(action: AppAction.counter, state: \.counterState)
/// )
/// ```
///
/// Or use the convenience factory ``StoreType/asObservableStore()``:
///
/// ```swift
/// @State var vm = appStore
///     .projection(action: AppAction.counter, state: \.counterState)
///     .buffer()
///     .asObservableStore()
/// ```
///
/// ## iOS version guidance
///
/// | iOS | Recommended wrapper | Property wrapper |
/// | --- | --- | --- |
/// | 15+ | ``ObservableObjectStore`` | `@StateObject` / `@ObservedObject` |
/// | 17+ | ``ObservableStore`` | `@State` |
///
/// On iOS 15/16, fall back to ``ObservableObjectStore``.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@Observable
@MainActor
public final class ObservableStore<Action: Sendable, State: Sendable>: StoreType {
    /// The current store state, stored so `@Observable`'s registrar tracks field access.
    ///
    /// Updated after every mutation via the store's `didChange` callback. Reading individual
    /// fields of this property inside a SwiftUI `body` registers per-field dependencies —
    /// only views that read a changed field re-render.
    public private(set) var state: State

    private let store: any StoreType<Action, State>
    private var token: SubscriptionToken?

    public init(_ store: some StoreType<Action, State>) {
        self.store = store
        self.state = store.state
        token = self.store.observe(
            willChange: {},
            didChange: { [weak self] in
                guard let self else { return }
                self.state = self.store.state   // @Observable registrar fires tracking notifications
            }
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
#endif
