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
    /// - **`.present(wrapped)`** → `slot = .presented(wrapped)` (open, seeding the child state);
    /// - **`.dismiss`** → `slot = slot.dismiss()` — the single stage-dependent step
    ///   (`presented → dismissing → dismissed`), dispatched once by the view binding and once by
    ///   `onDismiss`;
    /// - **`.child(_)`** → the child behavior, run while the slot is `presented` **or** `dismissing`
    ///   (so late effects still land), its actions re-embedded and its state read/written through
    ///   `slot.wrapped`.
    ///
    /// ```swift
    /// DetailFeature.behavior().liftPresentation(
    ///     action: \.detail,     // Action.detail: PresentationAction<DetailFeature.State, DetailFeature.Action>
    ///     state:  \.detail,     // State.detail:  Presentation<DetailFeature.State>
    ///     environment: { $0.detailEnv }
    /// )
    /// ```
    public func liftPresentation<GlobalAction: Sendable, GlobalState: Sendable, GlobalEnvironment: Sendable>(
        action outer: Prism<GlobalAction, PresentationAction<Action>>,
        state slot: WritableKeyPath<GlobalState, Presentation<State>>,
        environment narrow: @escaping @Sendable (GlobalEnvironment) -> Environment
    ) -> Behavior<GlobalAction, GlobalState, GlobalEnvironment> {
        // Child actions travel as `.child(_)` inside the presentation action — a prism through both hops.
        let childAction = Prism<GlobalAction, Action>(
            preview: { global in
                guard case let .child(childAction)? = outer.preview(global) else { return nil }
                return childAction
            },
            review: { childAction in outer.review(.child(childAction)) }
        )

        // `dismiss` — the pure stage machine on the presentation slot. (Presenting is the parent's own
        // reducer setting `slot = .presented(_)`, so it never needs the child State in the action.)
        let control = Behavior<GlobalAction, GlobalState, GlobalEnvironment>.reduce { global, state in
            switch outer.preview(global) {
            case .dismiss?: state[keyPath: slot] = state[keyPath: slot].dismiss()
            case .child?, nil: break
            }
        }

        // The child behavior, focused on `slot.wrapped` (present while presented or dismissing).
        let child = liftAction(childAction)
            .liftOptional(slot.appending(path: \Presentation<State>.wrapped))
            .liftEnvironment(narrow)

        return Behavior<GlobalAction, GlobalState, GlobalEnvironment>.combine(control, child)
    }

    /// `\.case` key-path spelling of ``liftPresentation(action:state:environment:)-(Prism<_,_>,_,_)`` —
    /// pass `action: \.detail` instead of a `Prism`.
    public func liftPresentation<GlobalAction: Prismatic & Sendable, GlobalState: Sendable, GlobalEnvironment: Sendable>(
        action path: PrismKeyPath<GlobalAction, PresentationAction<Action>>,
        state slot: WritableKeyPath<GlobalState, Presentation<State>>,
        environment narrow: @escaping @Sendable (GlobalEnvironment) -> Environment
    ) -> Behavior<GlobalAction, GlobalState, GlobalEnvironment> {
        liftPresentation(action: Prism(path), state: slot, environment: narrow)
    }
}

#endif
