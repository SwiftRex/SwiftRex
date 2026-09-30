// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import SwiftRex

    // `transpose` — swap `ViewStore<T?>` (or `ViewStore<Presentation<T>>`) into `ViewStore<T>?`, so an optional child
    // screen exists exactly when its state does: `if let child = viewStore.focus(…).transpose() { ChildView(viewStore: child) }`.
    // It's a read, so it lives here: the caller depends on the **presence edge only**, never on the child's contents, and the child is a view store on the
    // same engine — no new subscription, no owner needed — that holds its last present value while it's dismissed.
    //
    //   • `T?`                — present while `.some`.
    //   • `Presentation<T>`   — present through **both** `presented` and `dismissing(last:)`, `nil` only once
    //                           `dismissed`, so the child stays alive and steady while SwiftUI animates it out.
    //   • a closure lane      — `viewStore.transpose(action:state:)`, for what no key path expresses.

    extension ViewStore {
        /// Swap `ViewStore<T?>` into `ViewStore<T>?`, depending only on the presence edge.
        ///
        /// ```swift
        /// if let book = viewStore.focus(.action(\.book).state(\.book)).transpose() {
        ///     BookView(viewStore: book)
        /// }
        /// ```
        public func transpose<Wrapped: Sendable>() -> ViewStore<Action, Wrapped>? where State == Wrapped? {
            unwrapping(reader, stateStream)
        }

        /// Swap `ViewStore<Presentation<T>>` into `ViewStore<T>?`: a view store of the presented value while
        /// `presented` **or** `dismissing`, `nil` once `dismissed`.
        ///
        /// ```swift
        /// if let editor = viewStore.focus(.action(\.editor.child).state(\.editor)).transpose() {
        ///     EditorView(viewStore: editor)
        /// }
        /// ```
        public func transpose<Wrapped: Sendable>() -> ViewStore<Action, Wrapped>? where State == Presentation<Wrapped> {
            unwrapping(reader.slice(\Presentation<Wrapped>.wrapped), stateStream.map(\.wrapped))
        }

        private func unwrapping<Wrapped: Sendable>(
            _ optional: any TrackingReader<Wrapped?>,
            _ stream: StateStream<Wrapped?>
        ) -> ViewStore<Action, Wrapped>? {
            guard optional.read(\Wrapped?.observationIsPresent), let current = optional.peekWhole() else { return nil }
            return ViewStore<Action, Wrapped>(
                reader: optional.slice(\Wrapped?.[observationUnwrapped: ObservationLastPresent(current)]),
                send: dispatch,
                stateStream: stream.holdingLastPresent(fallback: current)
            )
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
