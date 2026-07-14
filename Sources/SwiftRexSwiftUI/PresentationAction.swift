// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
/// The standard action set for a ``Presentation`` slot — a `dismiss` command plus a pass-through for the
/// presented child's own actions. It is generic **only over the child's `Action`** — never its `State` —
/// so nothing drags state into your action type. Nest one case in your feature's `Action`
/// (`case detail(PresentationAction<Detail.Action>)`) and pair it with a `Presentation<Detail.State>`
/// slot in your `State`; ``Behavior/liftPresentation(action:state:environment:)`` consumes exactly that
/// `(action prism, state lens)` pair.
///
/// **Presenting is not an action here** — the parent owns navigation state, and it has the value to show
/// in hand, so it simply sets the slot in its own reducer: `state.detail = .presented(childState)`. That
/// keeps `PresentationAction` free of the child `State` type.
///
/// `dismiss` is the **single** stage-dependent command: dispatched once by the binding's `set(false)`
/// (`presented → dismissing`) and once by SwiftUI's `onDismiss` (`dismissing → dismissed`).
public enum PresentationAction<Child> {
    /// Advance the dismissal one stage (stage-dependent — see ``Presentation/dismiss()``).
    case dismiss
    /// An action from the presented child.
    case child(Child)
}

extension PresentationAction: Sendable where Child: Sendable {}
extension PresentationAction: Equatable where Child: Equatable {}

#endif
