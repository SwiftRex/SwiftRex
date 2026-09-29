// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import DataStructure
    import SwiftRex
    import SwiftRexSwiftUI

    // The store `@Feature`'s generated `view(store:environment:)` builds. The composition is fixed —
    // `[buffer] → projection(map) → observable` — and the only choice, whether to buffer before the map, is
    // made by the type checker: when the feature's `State` is `Equatable` the overload that buffers wins, so
    // `mapState` runs only when the feature's own state changed (one `==` per upstream change instead of a
    // map per upstream change). After the map, the observable store's per-path diff does the rest.

    extension ObservableStore {
        /// A feature's view store: `store` projected through the environment-aware maps, observed.
        public static func feature<FeatureAction: Sendable, FeatureState: Sendable, Environment>(
            _ store: any StoreType<FeatureAction, FeatureState>,
            environment: Environment,
            action mapAction: Reader<Environment, @Sendable (Action) -> FeatureAction>,
            state mapState: Reader<Environment, @MainActor @Sendable (FeatureState) -> State>,
            strategy: ViewStrategy
        ) -> ObservableStore {
            store.projection(environment: environment, action: mapAction, state: mapState).observable(strategy)
        }

        /// A feature's view store when its `State` is `Equatable`: buffered **before** the map, so the map
        /// runs only when the feature's state changed.
        public static func feature<FeatureAction: Sendable, FeatureState: Sendable & Equatable, Environment>(
            _ store: any StoreType<FeatureAction, FeatureState>,
            environment: Environment,
            action mapAction: Reader<Environment, @Sendable (Action) -> FeatureAction>,
            state mapState: Reader<Environment, @MainActor @Sendable (FeatureState) -> State>,
            strategy: ViewStrategy
        ) -> ObservableStore {
            store.buffer().projection(environment: environment, action: mapAction, state: mapState).observable(strategy)
        }

        /// A view-layer-less feature's view store: the feature's store, observed directly.
        public static func feature(_ store: any StoreType<Action, State>, strategy: ViewStrategy) -> ObservableStore {
            store.observable(strategy)
        }
    }
#endif
