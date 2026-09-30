// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import SwiftRex

    // `transpose` — swap `Store<T?>` (or `Store<Presentation<T>>`) into `Store<T>?`, so an optional child screen
    // exists exactly when its state does. It lives on `ViewStore` because deciding presence is a *read*, and only a
    // view store can read: the caller depends on the **presence edge only**, never on the child's contents (the
    // child follows its own state through the returned projection). Three forms:
    //
    //   • `Presentation<T>` — present through **both** `presented` and `dismissing(last:)`, so the child stays
    //     alive and steady while SwiftUI animates the sheet out; `nil` only once `dismissed` (no flicker).
    //   • `T?` — focus the slot first: `viewStore.focus(.state(\.child), .action(\.child)).transpose()`.
    //   • a closure lane — `viewStore.transpose(action:state:)`, for what no key path expresses (an affine preview).
    //
    // It's named transpose, not `sequence`: a store isn't `Traversable`, only peekable — the current value decides
    // the nesting. The returned projection holds the last present value once it disappears (each observer its own).

    extension ViewStore {
        /// Swap `Store<Presentation<T>>` into `Store<T>?`: a projection onto the presented value while `presented`
        /// **or** `dismissing`, `nil` while `dismissed`.
        ///
        /// ```swift
        /// if let editor = viewStore.focus(.state(\.editor), .action(\.editor)).transpose() {
        ///     EditorFeature.view(store: editor, environment: world.editorEnv)
        /// }
        /// ```
        public func transpose<Wrapped: Sendable>() -> StoreProjection<Action, Wrapped>? where State == Presentation<Wrapped> {
            reader.read(\Presentation<Wrapped>.wrapped.observationIsPresent)
                ? reader.peek(\Presentation<Wrapped>.wrapped).map { current in
                    StoreProjection(store: self, action: { $0 }, stateStream: stateStream.map(\.wrapped).holdingLastPresent(fallback: current))
                }
                : nil
        }

        /// Swap `Store<T?>` into `Store<T>?`, depending only on the presence edge.
        ///
        /// ```swift
        /// if let book = viewStore.focus(.state(\.book), .action(\.book)).transpose() {
        ///     BookFeature.view(store: book, environment: world.bookEnv)
        /// }
        /// ```
        public func transpose<Wrapped: Sendable>() -> StoreProjection<Action, Wrapped>? where State == Wrapped? {
            reader.read(\Wrapped?.observationIsPresent)
                ? reader.peekWhole().map { current in
                    StoreProjection(store: self, action: { $0 }, stateStream: stateStream.holdingLastPresent(fallback: current))
                }
                : nil
        }

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
        ) -> StoreProjection<LocalAction, Wrapped>? {
            let present = read(
                derived: { state($0) != nil },
                types: [ObjectIdentifier(LocalAction.self), ObjectIdentifier(Wrapped.self)],
                id: id,
                site: "\(fileID):\(line):\(column)"
            )
            return present
                ? state(reader.peekWhole()).map { current in
                    StoreProjection(store: self, action: action, stateStream: stateStream.map(state).holdingLastPresent(fallback: current))
                }
                : nil
        }
    }
#endif
