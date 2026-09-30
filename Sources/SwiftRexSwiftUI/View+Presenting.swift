// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
    import SwiftRex
    import SwiftUI

    extension View {
        /// Presents a **sheet** driven by a ``Presentation`` slot, wiring **both** `dismiss` dispatches
        /// so the state can never get stuck mid-dismiss:
        /// - the binding's `set(false)` (swipe / tap-out) dispatches `dismiss` → `presented → dismissing`;
        /// - `onDismiss` (animation complete) dispatches the same `dismiss` → `dismissing → dismissed`.
        ///
        /// `content` receives the currently-`wrapped` value (present through `presented` **and**
        /// `dismissing`), so the sheet renders the last value unchanged as it animates out. Read the
        /// store inside `content` to build a *live* child (e.g. `Relay.Scope.view(of:from:world:)`); the passed
        /// value is the same slice for simple, value-only content.
        ///
        /// The binding is a `Bool`, so SwiftUI's identity never churns on child-state changes — the safe
        /// default. For a cover or popover, use `store.presence(…)` with `.fullScreenCover(isPresented:)` /
        /// `.popover(isPresented:)` and dispatch the same `dismiss` from their `onDismiss`.
        @MainActor
        public func presenting<Action: Sendable, State: Sendable, Wrapped: Sendable, Presented: View>(
            _ store: ViewStore<Action, State>,
            _ keyPath: KeyPath<State, Presentation<Wrapped>>,
            dismiss: Action,
            onDismiss: (@MainActor () -> Void)? = nil,
            file: String = #fileID,
            function: String = #function,
            line: UInt = #line,
            @ViewBuilder content: @escaping (Wrapped) -> Presented
        ) -> some View {
            sheet(
                isPresented: store.presence(
                    .state(keyPath),
                    dismiss: dismiss,
                    file: file,
                    function: function,
                    line: line
                ),
                onDismiss: {
                    store.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
                    onDismiss?()
                },
                content: {
                    if let wrapped = store.read(keyPath, \Presentation<Wrapped>.wrapped) {
                        content(wrapped)
                    }
                }
            )
        }

        /// The **simple** optional sheet — presents while a `Wrapped?` slot is `.some`, dispatching
        /// `dismiss` when SwiftUI clears it. There is no `dismissing(last:)` stage, so the content blanks
        /// as the sheet animates out (it ignores the dismissal frame). Reach for the ``Presentation``
        /// overload when that flicker matters; use this when it doesn't.
        @MainActor
        public func presenting<Action: Sendable, State: Sendable, Wrapped: Sendable, Presented: View>(
            _ store: ViewStore<Action, State>,
            _ keyPath: KeyPath<State, Wrapped?>,
            dismiss: Action,
            onDismiss: (@MainActor () -> Void)? = nil,
            file: String = #fileID,
            function: String = #function,
            line: UInt = #line,
            @ViewBuilder content: @escaping (Wrapped) -> Presented
        ) -> some View {
            sheet(
                isPresented: store.presence(
                    .state(keyPath),
                    dismiss: dismiss,
                    file: file,
                    function: function,
                    line: line
                ),
                onDismiss: onDismiss,
                content: {
                    if let wrapped = store.read(keyPath) {
                        content(wrapped)
                    }
                }
            )
        }

        /// `.sheet(item:)` counterpart of ``presenting(_:_:dismiss:onDismiss:file:function:line:content:)-(_,KeyPath<_,Presentation<_>>,_,_,_,_,_,_)``
        /// for an `Identifiable` presented value — wires both `dismiss` edges, and keys the sheet on
        /// `id` (via the `Presentation` overload of `item(_:dismiss:)`) so a mutating child
        /// never churns SwiftUI's identity. `content` receives the item.
        @MainActor
        public func presentingItem<Action: Sendable, State: Sendable, Wrapped: Identifiable & Sendable, Presented: View>(
            _ store: ViewStore<Action, State>,
            _ keyPath: KeyPath<State, Presentation<Wrapped>>,
            dismiss: Action,
            onDismiss: (@MainActor () -> Void)? = nil,
            file: String = #fileID,
            function: String = #function,
            line: UInt = #line,
            @ViewBuilder content: @escaping (Wrapped) -> Presented
        ) -> some View {
            sheet(
                item: store.item(
                    .state(keyPath),
                    dismiss: dismiss,
                    file: file,
                    function: function,
                    line: line
                ),
                onDismiss: {
                    store.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
                    onDismiss?()
                },
                content: content
            )
        }
    }
#endif
