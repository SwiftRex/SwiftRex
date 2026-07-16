// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    import SwiftRex
    import SwiftUI

    // MARK: - Multi-scene from a single store

//
    // Multiple windows/scenes are still ONE store. Model open scenes as state (a dictionary or
    // identifiable collection of per-scene sub-states); each window projects its own slice by id with
    // the existing element/dictionary projection; open/close are ordinary actions. No new machinery.
//
//     @main struct MyApp: App {
//         let store = Store(initial: AppState(), behavior: appBehavior, environment: world)
//         var body: some Scene {
//             WindowGroup { RootView(store: store, world: world) }          // main window
//             WindowGroup(for: DocID.self) { $id in                          // document windows
//                 if let id { DocumentScene(store: store, world: world, id: id) }
//             }
//         }
//     }
//
    // `DocumentScene` projects `store.projection(key: id, actionReview:, stateDictionary:)` for that
    // window's slice and builds its feature view — the same router/scope wiring as in-window navigation,
    // one level up. `openWindow(value:)` / `dismissWindow` are driven by dispatching actions that add or
    // remove a scene's sub-state; the window set is a function of state.

    /// A convenience that reads whether a scene id currently has state — for a window body to decide
    /// between rendering its content and dismissing itself (e.g. `if store.hasScene(id, in: \.documents)`).
    extension StoreType {
        /// `true` while a scene with `id` exists in the keyed sub-state collection — i.e. the window
        /// should still render. Pair with `dismissWindow` when it becomes `false`.
        @MainActor
        public func hasScene<Key: Hashable & Sendable, Value>(
            _ id: Key,
            in dictionary: KeyPath<State, [Key: Value]>
        ) -> Bool {
            state[keyPath: dictionary][id] != nil
        }
    }
#endif
