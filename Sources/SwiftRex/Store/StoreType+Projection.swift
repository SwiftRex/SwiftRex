// SPDX-License-Identifier: Apache-2.0

import DataStructure

extension StoreType {
    /// Creates a ``StoreProjection`` that narrows this store to a local action and state interface through
    /// closures.
    ///
    /// The projection holds no state of its own — its ``StoreProjection/stateStream`` is this store's stream
    /// mapped through `mapState`, once per upstream change for each observer. Actions dispatched to the
    /// projection are transformed by `mapAction` before reaching the underlying store.
    ///
    /// For a plain slice, project through a ``Relay/Scope`` instead —
    /// `appStore.projection(.action(\.counter).state(\.counter))`. The closure form is for a derived view
    /// state no key path expresses:
    ///
    /// ```swift
    /// let counterView = counterStore.projection(
    ///     action: { $0 },
    ///     state: { CounterViewState(label: "\($0.count)", canDecrement: $0.count > 0) }
    /// )
    /// // counterView: StoreProjection<CounterAction, CounterViewState>
    /// ```
    ///
    /// Delegates to ``StoreProjection/init(store:action:state:)``.
    ///
    /// - Parameters:
    ///   - mapAction: Converts a local `LocalAction` into this store's `Action` type.
    ///   - mapState: Projects this store's `State` type to the local `LocalState`.
    /// - Returns: A ``StoreProjection`` presenting the narrower `(LocalAction, LocalState)` interface.
    public func projection<LocalAction: Sendable, LocalState: Sendable>(
        action mapAction: @escaping @Sendable (LocalAction) -> Action,
        state mapState: @escaping @MainActor @Sendable (State) -> LocalState
    ) -> StoreProjection<LocalAction, LocalState> {
        StoreProjection(store: self, action: mapAction, state: mapState)
    }

    /// Creates a ``StoreProjection`` whose action **and** state maps are `Reader`s over an
    /// `Environment`, applied with `environment` at creation.
    ///
    /// The environment-aware counterpart of `projection(action:state:)` (which is the
    /// `Environment == Void` case). Use it when the projection depends on live dependencies on
    /// either side — locale-aware formatting on the state map, resilient/locale-aware parsing on
    /// the action map. Whoever projects supplies the environment (they hold the underlying store).
    ///
    /// ```swift
    /// let counterStore = appStore.projection(
    ///     environment: world,
    ///     action: Reader { env in { CounterAction.edited($0, env.locale) } },
    ///     state: Reader { env in { env.format($0.count) } }
    /// )
    /// ```
    ///
    /// Delegates to ``StoreProjection/init(store:environment:action:state:)``.
    ///
    /// - Parameters:
    ///   - environment: The environment supplied to both maps.
    ///   - mapAction: A `Reader<Environment, (LocalAction) -> Action>`.
    ///   - mapState: A `Reader<Environment, (State) -> LocalState>`.
    /// - Returns: A ``StoreProjection`` presenting the narrower `(LocalAction, LocalState)` interface.
    public func projection<LocalAction: Sendable, LocalState: Sendable, Environment>(
        environment: Environment,
        action mapAction: Reader<Environment, @Sendable (LocalAction) -> Action>,
        state mapState: Reader<Environment, @MainActor @Sendable (State) -> LocalState>
    ) -> StoreProjection<LocalAction, LocalState> {
        StoreProjection(store: self, environment: environment, action: mapAction, state: mapState)
    }
}
