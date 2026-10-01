// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
import CoreFP
import SwiftRex

// MARK: - Presentation lift

extension Behavior {
    /// Lifts a child behavior into a parent that drives it through a ``Presentation`` slot and a
    /// ``PresentationAction`` — the modal / sheet / destination counterpart of an optional-state
    /// (affine) ``Relay/Scope`` lift,
    /// but over the three-stage presentation lifecycle instead of a bare `Optional`.
    ///
    /// It folds three things into one behavior:
    /// - **`.dismiss`** → `slot = slot.dismiss()` — the dismissal started (`presented → dismissing(last:)`),
    ///   dispatched by the view binding going `false`/`nil`, or by you to dismiss programmatically;
    /// - **`.dismissed`** → `slot = .dismissed` — SwiftUI's `onDismiss`, when the animation ended;
    /// - **`.child(_)`** → the child behavior, run while the slot is `presented` **or** `dismissing`
    ///   (so late effects still land), its actions re-embedded and its state read/written through
    ///   `slot.wrapped`.
    ///
    /// ```swift
    /// DetailFeature.behavior().liftPresentation(.action(\.detail).state(\.detail).environment { $0.detailEnv })
    /// // Action.detail: PresentationAction<DetailFeature.Action>, State.detail: Presentation<DetailFeature.State>
    /// ```
    ///
    /// Takes a ``Relay/Scope`` like every other lift — an inline chain or a declared `ScopeOf` scope: a duplex action
    /// lane into the `PresentationAction`, a writing state lane into the `Presentation` slot, a narrowing environment.
    public func liftPresentation<
        A: Relay.ActionAxis.ExtractsProtocol & Relay.ActionAxis.EmbedsProtocol,
        S: Relay.StateAxis.WritesProtocol,
        E: Relay.EnvironmentAxis.NarrowsProtocol
    >(
        _ scope: Relay.Scope<A.Global, A, S.Global, S, E.Global, E>
    ) -> Behavior<A.Global, S.Global, E.Global>
    where A.Local == PresentationAction<Action>, S.Local == Presentation<State>, E.Local == Environment {
        // Child actions travel as `.child(_)` inside the presentation action — a prism through both hops.
        let childAction = Prism<A.Global, Action>(
            preview: { global in
                guard case let .child(childAction)? = scope.action.preview(global) else { return nil }
                return childAction
            },
            review: { childAction in scope.action.review(.child(childAction)) }
        )

        // The two dismissal edges — the pure stage machine on the presentation slot. (Presenting is the parent's
        // own reducer setting `slot = .presented(_)`, so it never needs the child State in the action.)
        let control = Behavior<A.Global, S.Global, E.Global>.reduce { global, state in
            switch scope.action.preview(global) {
            case .dismiss?: scope.state.modify(&state) { $0 = $0.dismiss() }
            case .dismissed?: scope.state.modify(&state) { $0 = .dismissed }
            case .child?, nil: break
            }
        }

        // The child behavior, focused on `slot.wrapped` (present while presented or dismissing).
        let wrapped = AffineTraversal<S.Global, State>(
            preview: { scope.state.preview($0)?.wrapped },
            setMut: { whole, part in scope.state.modify(&whole) { $0.wrapped = part } }
        )
        let child = liftAction(childAction)
            .liftOptional(Relay.Scope(action: Relay.Identity(), state: Relay.StateAxis.Writes(wrapped), environment: Relay.Identity()))
            .liftEnvironment(scope.environment.narrow)

        return Behavior<A.Global, S.Global, E.Global>.combine(control, child)
    }
}

#endif
