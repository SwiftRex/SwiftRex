// SPDX-License-Identifier: Apache-2.0

/// A store with an identity — what a list iterates: `ForEach(viewStore.each(scope)) { row in RowView(store: row) }`.
/// A pure stage: it follows and dispatches through the store it wraps, adding only `id`.
@MainActor
public struct IdentifiedStore<ID: Hashable & Sendable, Base: StoreType>: StoreType, Identifiable {
    public let id: ID
    public let store: Base

    public init(id: ID, store: Base) {
        self.id = id
        self.store = store
    }

    public var stateStream: StateStream<Base.State> { store.stateStream }

    public func dispatch(_ action: Base.Action, source: ActionSource) {
        store.dispatch(action, source: source)
    }
}
