#if canImport(Observation)
import Observation
import SwiftRex

/// A `@MainActor` SwiftUI view model that wraps any `StoreType` and adds `@Observable`
/// conformance for iOS 17+.
///
/// `state` is a stored property so `@Observable`'s registrar can track access and invalidate
/// exactly the views that read changed fields — no full re-render on unrelated mutations.
///
/// Use `StoreType.projection(action:state:)` first if you need action or state mapping,
/// then wrap the result here.
///
/// ```swift
/// @State var vm = ObservableStore(
///     appStore.projection(action: AppAction.counter, state: \.counterState)
/// )
/// ```
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@Observable
@MainActor
public final class ObservableStore<Action: Sendable, State: Sendable>: StoreType {

    /// Stored so `@Observable`'s registrar can track which fields views read.
    /// Updated after every mutation via the store's `didChange` callback.
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
        didChange:  @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken {
        store.observe(willChange: willChange, didChange: didChange)
    }
}
#endif
