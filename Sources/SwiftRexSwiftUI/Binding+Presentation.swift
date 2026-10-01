// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
    import SwiftUI

    // A `Binding<Presentation<T>>` (from `viewStore.binding(.state(\.slot).action(\.slot))`) is a presentation's two
    // dismiss edges in one value. SwiftUI splits them across two parameters — the binding going `false`/`nil` when
    // dismissal *starts* (swipe, tap-out, a programmatic dismiss), and `onDismiss:` when the animation *ends* — so
    // these accessors hand each parameter its part: the first edge writes `dismissing(last:)` back, the second
    // `dismissed` — which the view store's binding turns into `PresentationAction.dismiss` and `.dismissed`.

    extension Binding {
        /// `true` only while `presented` — for `isPresented:` parameters. Setting `false` starts the dismissal.
        /// Pair it with ``onDismiss()``.
        public func isPresented<Wrapped>() -> Binding<Bool> where Value == Presentation<Wrapped> {
            self[dynamicMember: \Presentation<Wrapped>.presentedFlag]
        }

        /// The presented value while `presented`, `nil` otherwise — for `item:` parameters. Setting `nil` starts the
        /// dismissal. Pair it with ``onDismiss()``.
        public func item<Wrapped>() -> Binding<Wrapped?> where Value == Presentation<Wrapped> {
            self[dynamicMember: \Presentation<Wrapped>.presentedItem]
        }

        /// The second edge — for `onDismiss:` parameters: once SwiftUI finishes animating out, the slot moves from
        /// `dismissing` to `dismissed`.
        public func onDismiss<Wrapped>() -> () -> Void where Value == Presentation<Wrapped> {
            { wrappedValue = .dismissed }
        }
    }

    // The two writable views of a presentation the accessors above project through `Binding`'s own key-path
    // subscript — the native way to derive a binding, with no closures capturing the source binding.
    extension Presentation {
        /// `isPresented`, writable: writing `false` advances the dismissal one stage.
        var presentedFlag: Bool {
            get { isPresented }
            set { if !newValue { self = dismiss() } }
        }

        /// The value while `presented`, `nil` otherwise; writing `nil` advances the dismissal one stage.
        var presentedItem: Wrapped? {
            get { isPresented ? wrapped : nil }
            set { if newValue == nil { self = dismiss() } }
        }
    }

    extension View {
        /// Presents a sheet from a ``Presentation`` binding, wiring **both** dismiss edges — it is
        /// `.sheet(item: presentation.item(), onDismiss: presentation.onDismiss(), content:)`:
        ///
        /// ```swift
        /// .sheet(item: viewStore.binding(.state(\.editor).action(\.editor))) { _ in
        ///     if let editor = viewStore.traverse(.action(\.editor.child).state(\.editor)) {
        ///         EditorFeature.view(store: editor, environment: world.editorEnv)   // the feature's view owns it
        ///     }
        /// }
        /// ```
        ///
        /// SwiftUI keys the sheet on the value's `id`. Build the sheet's content from the view store
        /// (`traverse(scope)`, owned by the child's view), which stays live and holds the last value while the sheet
        /// animates out; the value passed to `content` is the one that opened it.
        public func sheet<Wrapped: Identifiable, Content: View>(
            item presentation: Binding<Presentation<Wrapped>>,
            @ViewBuilder content: @escaping (Wrapped) -> Content
        ) -> some View {
            sheet(item: presentation.item(), onDismiss: presentation.onDismiss(), content: content)
        }
    }
#endif
