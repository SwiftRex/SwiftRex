import Foundation

/// A type-erased projection of a `StoreType` that maps its action and state types to a
/// narrower local interface. Holds no state — `state` is computed from the underlying
/// store on every access.
///
/// Create projections via `StoreType.projection(action:state:)`:
///
/// ```swift
/// let counterProjection = appStore.projection(
///     action: AppAction.counter,     // LocalAction → GlobalAction
///     state:  \.counterState         // GlobalState → LocalState
/// )
/// ```
///
/// The ViewModel / ObservableObject layer that owns the projection and drives SwiftUI
/// re-rendering is a separate concern implemented on top of `StoreType`.
@MainActor
public struct StoreProjection<Action: Sendable, State: Sendable>: StoreType {

    private let _state:    @MainActor @Sendable () -> State
    private let _dispatch: @MainActor @Sendable (Action, ActionSource) -> Void
    private let _observe:  @MainActor @Sendable (
        @escaping @MainActor @Sendable () -> Void,
        @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken

    package init(
        state:    @escaping @MainActor @Sendable () -> State,
        dispatch: @escaping @MainActor @Sendable (Action, ActionSource) -> Void,
        observe:  @escaping @MainActor @Sendable (
            @escaping @MainActor @Sendable () -> Void,
            @escaping @MainActor @Sendable () -> Void
        ) -> SubscriptionToken
    ) {
        _state    = state
        _dispatch = dispatch
        _observe  = observe
    }

    public var state: State { _state() }

    public func dispatch(_ action: Action, source: ActionSource) {
        _dispatch(action, source)
    }

    @discardableResult
    public func observe(
        willChange: @escaping @MainActor @Sendable () -> Void,
        didChange:  @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken {
        _observe(willChange, didChange)
    }
}
