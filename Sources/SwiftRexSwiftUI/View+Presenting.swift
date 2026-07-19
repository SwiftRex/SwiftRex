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
        /// default. Cover / popover are analogous (`presentingCover` / `presentingPopover`).
        @MainActor
        public func presenting<S: StoreType, Wrapped: Sendable, Presented: View>(
            _ store: S,
            _ keyPath: KeyPath<S.State, Presentation<Wrapped>>,
            dismiss: S.Action,
            onDismiss: (@MainActor () -> Void)? = nil,
            file: String = #fileID,
            function: String = #function,
            line: UInt = #line,
            @ViewBuilder content: @escaping (Wrapped) -> Presented
        ) -> some View {
            sheet(
                isPresented: store.presence(
                    .state(keyPath) as Relay.StateAxis.Reads<S.State, Presentation<Wrapped>>,
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
                    if let wrapped = store.state[keyPath: keyPath].wrapped {
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
        public func presenting<S: StoreType, Wrapped: Sendable, Presented: View>(
            _ store: S,
            _ keyPath: KeyPath<S.State, Wrapped?>,
            dismiss: S.Action,
            onDismiss: (@MainActor () -> Void)? = nil,
            file: String = #fileID,
            function: String = #function,
            line: UInt = #line,
            @ViewBuilder content: @escaping (Wrapped) -> Presented
        ) -> some View {
            sheet(
                isPresented: store.presence(
                    .state(keyPath) as Relay.StateAxis.Reads<S.State, Wrapped?>,
                    dismiss: dismiss,
                    file: file,
                    function: function,
                    line: line
                ),
                onDismiss: onDismiss,
                content: {
                    if let wrapped = store.state[keyPath: keyPath] {
                        content(wrapped)
                    }
                }
            )
        }

        /// `.sheet(item:)` counterpart of ``presenting(_:_:dismiss:onDismiss:file:function:line:content:)-(_,KeyPath<_,Presentation<_>>,_,_,_,_,_,_)``
        /// for an `Identifiable` presented value — wires both `dismiss` edges, and keys the sheet on
        /// `id` (via ``StoreType/item(_:dismiss:file:function:line:)``) so a mutating child
        /// never churns SwiftUI's identity. `content` receives the item.
        @MainActor
        public func presentingItem<S: StoreType, Wrapped: Identifiable & Sendable, Presented: View>(
            _ store: S,
            _ keyPath: KeyPath<S.State, Presentation<Wrapped>>,
            dismiss: S.Action,
            onDismiss: (@MainActor () -> Void)? = nil,
            file: String = #fileID,
            function: String = #function,
            line: UInt = #line,
            @ViewBuilder content: @escaping (Wrapped) -> Presented
        ) -> some View {
            sheet(
                item: store.item(
                    .state(keyPath) as Relay.StateAxis.Reads<S.State, Presentation<Wrapped>>,
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
