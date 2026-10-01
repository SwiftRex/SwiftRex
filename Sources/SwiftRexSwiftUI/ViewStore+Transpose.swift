// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import SwiftRex

    // `transpose` — swap a store of an optional into an optional store: `F<T?>` into `F<T>?`. Deciding *whether* the
    // value is there is a **read**, so it lives on the view store (the only store that reads), and the caller depends
    // on the **presence edge only**, never on the child's contents. What comes back is a **pure stage** — a
    // `StoreOptionalFocus` built on this view store's pure side — that holds its last present value while the child animates
    // away. To observe it, own it: a feature's view (`Feature.view(store:)`), ``ProjectionKeeper`` in a body,
    // ``OwnedStore`` as a property.
    //
    //   • `T?`                 — present while `.some`.
    //   • `Presentation<T>`    — present through **both** `presented` and `dismissing(last:)`, `nil` only once `dismissed`.
    //   • a collection element — `transpose(scope, element: id)`: present while the element is in the collection.
    //   • a closure lane       — `transpose(action:state:)`, for what no key path expresses.

    extension ViewStore {
        // MARK: - This view store's own state

        /// Swap a view store of `T?` into a store of `T` — present while `.some`.
        ///
        /// ```swift
        /// if let book = viewStore.transpose() { ProjectionKeeper { book.viewStore() } content: { BookView(viewStore: $0) } }
        /// ```
        public func transpose<Wrapped: Sendable>() -> StoreOptionalFocus<Action, Wrapped>? where State == Wrapped? {
            reader.read(\Wrapped?.observationIsPresent)
                ? reader.peekWhole().map { StoreOptionalFocus(self, present: $0) }
                : nil
        }

        /// Swap a view store of `Presentation<T>` into a store of `T` — present while `presented` **or** `dismissing`.
        public func transpose<Wrapped: Sendable>() -> StoreOptionalFocus<Action, Wrapped>? where State == Presentation<Wrapped> {
            reader.read(\Presentation<Wrapped>.wrapped.observationIsPresent)
                ? reader.peekWhole().wrapped.map {
                    StoreOptionalFocus(StoreProjection(store: self, action: { $0 }, state: { $0.wrapped }), present: $0)
                }
                : nil
        }

        // MARK: - A slot of this view store's state

        /// The optional slot a scope reaches, as a store of its unwrapped value — present while the slot is `.some`.
        ///
        /// ```swift
        /// if let detail = viewStore.transpose(.action(\.detail).state(\.detail)) {
        ///     DetailFeature.view(store: detail, environment: world.detailEnv)     // the feature's view owns it
        /// }
        /// ```
        ///
        /// A key-path state lane depends on the slot's presence edge alone; a closure lane on its presence, compared
        /// per call site (pass `id` when one call site transposes different lanes of the same types).
        public func transpose<A: Relay.ActionAxis.EmbedsProtocol, S: Relay.StateAxis.ReadsProtocol, Wrapped: Sendable>(
            _ scope: Relay.Scope<Action, A, State, S, Never, Relay.Absurd<Never>>,
            id: AnyHashableSendable? = nil,
            fileID: String = #fileID,
            line: UInt = #line,
            column: UInt = #column
        ) -> StoreOptionalFocus<A.Local, Wrapped>? where A.Global == Action, S.Global == State, S.Local == Wrapped? {
            let reads = scope.state
            let present = reads.keyPath.map { reader.slice($0).read(\Wrapped?.observationIsPresent) }
                ?? read(
                    derived: { reads.get($0) != nil },
                    types: [ObjectIdentifier(A.Local.self), ObjectIdentifier(Wrapped.self)],
                    id: id,
                    site: "\(fileID):\(line):\(column)"
                )
            guard present, let current = reads.get(reader.peekWhole()) else { return nil }
            return StoreOptionalFocus(projection(action: scope.action.review, state: reads.get), present: current)
        }

        /// The ``Presentation`` slot a scope reaches, as a store of its presented value — present while `presented`
        /// **or** `dismissing`, so the child stays alive and steady while SwiftUI animates it out.
        ///
        /// ```swift
        /// .sheet(item: viewStore.binding(.state(\.editor).action(\.editor))) { _ in
        ///     if let editor = viewStore.transpose(.action(\.editor.child).state(\.editor)) {
        ///         EditorFeature.view(store: editor, environment: world.editorEnv)
        ///     }
        /// }
        /// ```
        public func transpose<A: Relay.ActionAxis.EmbedsProtocol, S: Relay.StateAxis.ReadsProtocol, Wrapped: Sendable>(
            _ scope: Relay.Scope<Action, A, State, S, Never, Relay.Absurd<Never>>,
            id: AnyHashableSendable? = nil,
            fileID: String = #fileID,
            line: UInt = #line,
            column: UInt = #column
        ) -> StoreOptionalFocus<A.Local, Wrapped>? where A.Global == Action, S.Global == State, S.Local == Presentation<Wrapped> {
            let reads = scope.state
            let present = reads.keyPath.map { reader.slice($0).read(\Presentation<Wrapped>.wrapped.observationIsPresent) }
                ?? read(
                    derived: { reads.get($0).wrapped != nil },
                    types: [ObjectIdentifier(A.Local.self), ObjectIdentifier(Presentation<Wrapped>.self)],
                    id: id,
                    site: "\(fileID):\(line):\(column)"
                )
            guard present, let current = reads.get(reader.peekWhole()).wrapped else { return nil }
            return StoreOptionalFocus(projection(action: scope.action.review, state: { reads.get($0).wrapped }), present: current)
        }

        // MARK: - One element of a collection

        /// One element of a collection, as a store of the element — present while it's in the collection. The same
        /// collection scope `projection(_:element:)` takes (by id, custom id, position or key), and the same
        /// `ElementAction` lane.
        ///
        /// ```swift
        /// ForEach(viewStore.state.each(\.rows)) { row in
        ///     if let rowStore = viewStore.transpose(.action(\.row).state(\.rows), element: row.id) {
        ///         RowFeature.view(store: rowStore, environment: world.rowEnv)      // or ProjectionKeeper { rowStore.viewStore() } …
        ///     }
        /// }
        /// ```
        ///
        /// The caller depends on the element's **presence** only. The row store is a pure `StoreOptionalFocus` over a
        /// `StoreCollectionFocus`: whoever owns it follows the element through its own hint (O(distance moved)) and holds
        /// the last value once the element is removed.
        public func transpose<A: Relay.ActionAxis.ElementProtocol, S: Relay.StateAxis.KeyedProtocol>(
            _ scope: Relay.Scope<Action, A, State, S, Never, Relay.Absurd<Never>>,
            element id: A.ID,
            fileID: String = #fileID,
            line: UInt = #line,
            column: UInt = #column
        ) -> StoreOptionalFocus<A.Local, S.Local>? where A.Global == Action, S.Global == State, A.ID == S.ID {
            let lane = scope.state
            let site = "\(fileID):\(line):\(column)"
            // This view store's own presence read keeps a hint too (its observation state, never a child's).
            let hint = reader.elementHint(AnyHashable([AnyHashable(site), AnyHashable(id)]))
            let locate: @Sendable (State) -> S.Local? = { lane.find(id, in: $0, hint: hint) }
            let present = read(
                derived: { locate($0) != nil },
                types: [ObjectIdentifier(A.Local.self), ObjectIdentifier(S.Local.self)],
                id: AnyHashableSendable(id),
                site: site
            )
            guard present, let current = locate(reader.peekWhole()) else { return nil }
            return StoreOptionalFocus(projection(scope, element: id), present: current)
        }

        // MARK: - A closure lane

        /// Projects through a **closure** lane and swaps `Store<T?>` into `Store<T>?` — depending only on the
        /// presence edge (`state(…) != nil`). The form for lanes no key path expresses — an affine `preview` (the
        /// top of a stack, an enum case), a `Relay.Scope`'s `state.preview` in a router:
        ///
        /// ```swift
        /// if let screen = viewStore.transpose(action: scope.action.review, state: scope.state.preview) {
        ///     Feature.view(store: screen, environment: scope.environment.narrow(world))
        /// }
        /// ```
        ///
        /// The presence dependency is identified by the call site plus the lane's types (see
        /// ``read(derived:id:fileID:line:column:)``); pass `id` when one call site transposes different lanes of
        /// the same types.
        public func transpose<LocalAction: Sendable, Wrapped: Sendable>(
            action: @escaping @Sendable (LocalAction) -> Action,
            state: @escaping @Sendable (State) -> Wrapped?,
            id: AnyHashableSendable? = nil,
            fileID: String = #fileID,
            line: UInt = #line,
            column: UInt = #column
        ) -> StoreOptionalFocus<LocalAction, Wrapped>? {
            let present = read(
                derived: { state($0) != nil },
                types: [ObjectIdentifier(LocalAction.self), ObjectIdentifier(Wrapped.self)],
                id: id,
                site: "\(fileID):\(line):\(column)"
            )
            guard present, let current = state(reader.peekWhole()) else { return nil }
            return StoreOptionalFocus(projection(action: action, state: state), present: current)
        }
    }
#endif
