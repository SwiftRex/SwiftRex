#if canImport(Combine)
import Combine
import SwiftRex

/// A `@MainActor` SwiftUI view model that wraps any `StoreType` and adds `ObservableObject`
/// conformance for iOS 15+.
///
/// `objectWillChange` fires **before** each mutation so SwiftUI animations capture the
/// correct pre-mutation snapshot. `state` reads live from the underlying store.
///
/// Use `StoreType.projection(action:state:)` first if you need action or state mapping,
/// then wrap the result here.
///
/// ```swift
/// @StateObject var vm = ObservableObjectStore(
///     appStore.projection(action: AppAction.counter, state: \.counterState)
/// )
/// ```
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
#endif
