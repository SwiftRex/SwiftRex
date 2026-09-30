// SPDX-License-Identifier: Apache-2.0

import SwiftRex
@testable import SwiftRexSwiftUI

// Test-only conveniences. Apps can't read a store or build a view store imperatively — tests can.
extension StoreType {
    /// The store's current state, for assertions.
    @MainActor var currentState: State { stateStream.subscribe { _ in }.current }

    /// A view store over this store, owned by the caller (the test).
    @MainActor func viewStore(_ strategy: ViewStrategy = .automatic) -> ViewStore<Action, State> {
        ViewStore(self, strategy: strategy)
    }
}

extension ViewStore {
    /// The engine's Combine signal (`objectWillChange`).
    @MainActor var testSignal: ViewStoreSignal { reader.signal }

    /// How many recorded dependencies are currently awaited on the engine (root view stores only).
    @MainActor var testArmedCount: Int? { (reader as? RootReader<Action, State>)?.engine.armedCount }
}

extension ViewStore {
    /// The strategy the engine signals SwiftUI through (root view stores only).
    @MainActor var testStrategy: ViewStrategy? { (reader as? RootReader<Action, State>)?.engine.strategy }
}
