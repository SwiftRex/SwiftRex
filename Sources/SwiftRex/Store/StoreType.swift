// SPDX-License-Identifier: Apache-2.0

/// The common interface of every store: send it actions, follow its state.
///
/// A store is **declarative**. There is no `state` to read at a given moment — you *observe* it through
/// ``stateStream`` (the current value first, then every change) and *act* on it through
/// ``dispatch(_:source:)``. Nothing that follows a store can peek into it, and nothing in a view can read a
/// store SwiftUI isn't observing: views read through a `ViewStore` (`SwiftRex.SwiftUI`), which keeps the
/// snapshot and records what each view read.
///
/// ```swift
/// let token = store.stateStream.observe { state in print(state.count) } // prints now, then on every change
/// store.dispatch(.increment)
/// ```
///
/// ## Conformers
///
/// | Type | Purpose |
/// |---|---|
/// | ``Store`` | Runs the app: owns the state, reduces actions, schedules effects — typically one per app |
/// | ``StoreProjection`` | Narrows action and state types: a mapped ``stateStream`` + a mapped dispatch |
/// | ``StoreBuffer`` | Skips states equal to the previous one (`Equatable`, or a predicate) |
/// | ``StoreCollectionFocus`` | One element of a collection (`Element?`), found through a per-observer hint |
/// | ``StoreOptionalFocus`` | A store of `T` over a store of `T?`, holding the last present value |
/// | ``IdentifiedStore`` | A store plus an `id`, for `ForEach` |
/// | `ViewStore` (`SwiftRex.SwiftUI`) | What SwiftUI views hold — adds a granular, observed `state` |
///
/// ## Dispatch
///
/// Calling ``dispatch(_:source:)`` enqueues an action into the ``Store``'s pipeline: behaviors run, the
/// mutation applies, ``stateStream`` observers receive the new state, then effects are scheduled. The
/// convenience overload ``dispatch(_:file:function:line:)`` captures the call site for provenance.
///
/// ## @MainActor
///
/// The whole surface is `@MainActor`: dispatching, observing and every delivered value happen on the main
/// actor, synchronously — so `withAnimation { store.dispatch(…) }` animates through every store that follows.
///
/// - Note: `StoreType` does not require `AnyObject`, so struct conformers (``StoreProjection``) are allowed.
@MainActor
public protocol StoreType<Action, State>: Sendable, Transceiver {
    /// The action type this store accepts.
    associatedtype Action: Sendable
    /// The state type this store manages.
    associatedtype State: Sendable

    /// The state over time: observing it delivers the current state immediately, then every new state.
    var stateStream: StateStream<State> { get }

    /// Dispatches an action with explicit call-site provenance.
    ///
    /// Prefer the convenience overload ``dispatch(_:file:function:line:)``, which captures the source
    /// automatically.
    ///
    /// - Parameters:
    ///   - action: The action to dispatch.
    ///   - source: The call-site origin of the dispatch.
    func dispatch(_ action: Action, source: ActionSource)
}

// MARK: - Convenience overloads

extension StoreType {
    /// Dispatches an action, automatically capturing the call site for provenance.
    ///
    /// `#file`, `#function`, and `#line` are resolved at the call site, so logging and
    /// analytics middleware always sees where the dispatch originated.
    ///
    /// Returns `self` so multiple dispatches can be chained in test code:
    ///
    /// ```swift
    /// store
    ///     .dispatch(.login(credentials))
    ///     .dispatch(.loadDashboard)
    /// ```
    ///
    /// - Parameters:
    ///   - action: The action to dispatch.
    ///   - file: Source file — captured automatically.
    ///   - function: Function name — captured automatically.
    ///   - line: Source line — captured automatically.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func dispatch(
        _ action: Action,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        dispatch(action, source: ActionSource(file: file, function: function, line: line))
        return self
    }
}
