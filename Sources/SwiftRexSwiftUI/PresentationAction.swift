// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
import FPMacros

/// The standard action set for a ``Presentation`` slot — the two dismissal edges plus a pass-through for the
/// presented child's own actions. It is generic **only over the child's `Action`** — never its `State` —
/// so nothing drags state into your action type. Nest one case in your feature's `Action`
/// (`case detail(PresentationAction<Detail.Action>)`) and pair it with a `Presentation<Detail.State>`
/// slot in your `State`; `liftPresentation(.action(\.detail).state(\.detail).environment(…))` consumes exactly
/// that pair.
///
/// **Presenting is not an action here** — the parent owns navigation state, and it has the value to show
/// in hand, so it simply sets the slot in its own reducer: `state.detail = .presented(childState)`. That
/// keeps `PresentationAction` free of the child `State` type.
///
/// SwiftUI reports a dismissal twice, and so does this action: `dismiss` when it **starts** (a swipe, a tap
/// outside, the binding going `false`/`nil` — `presented → dismissing(last:)`), `dismissed` when the animation
/// **ends** (SwiftUI's `onDismiss` — `→ dismissed`). A view store's `Binding<Presentation<T>>` dispatches both.
/// To dismiss programmatically, dispatch `dismiss` (or set `dismissing` in your reducer); SwiftUI's `onDismiss`
/// then sends `dismissed`.
@Prisms
public enum PresentationAction<Child> {
    /// The dismissal started: `presented → dismissing(last:)`. Ignored unless `presented`.
    case dismiss
    /// The dismissal finished (the animation ended): the slot becomes `dismissed`.
    case dismissed
    /// An action from the presented child.
    case child(Child)
}

extension PresentationAction: Sendable where Child: Sendable {}
extension PresentationAction: Equatable where Child: Equatable {}

#endif
