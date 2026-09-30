// SPDX-License-Identifier: Apache-2.0

import DataStructure
import SwiftRex

// The store `@Feature`'s generated view observes: the feature's store projected through its environment-aware
// maps. The only choice — whether to buffer before the map — is made by the type checker: when the feature's
// `State` is `Equatable` the overload that buffers wins, so `mapState` runs only when the feature's own state
// changed. After the map, the view store's per-path tracking does the rest.

extension StoreType {
    /// A feature's view projection: this store mapped through the environment-aware maps.
    public func featureProjection<ViewAction: Sendable, ViewState: Sendable, Environment>(
        environment: Environment,
        action mapAction: Reader<Environment, @Sendable (ViewAction) -> Action>,
        state mapState: Reader<Environment, @MainActor @Sendable (State) -> ViewState>
    ) -> StoreProjection<ViewAction, ViewState> {
        projection(environment: environment, action: mapAction, state: mapState)
    }

    /// A feature's view projection when its `State` is `Equatable`: buffered **before** the map, so the map
    /// runs only when the feature's state changed.
    public func featureProjection<ViewAction: Sendable, ViewState: Sendable, Environment>(
        environment: Environment,
        action mapAction: Reader<Environment, @Sendable (ViewAction) -> Action>,
        state mapState: Reader<Environment, @MainActor @Sendable (State) -> ViewState>
    ) -> StoreProjection<ViewAction, ViewState> where State: Equatable {
        buffer().projection(environment: environment, action: mapAction, state: mapState)
    }
}
