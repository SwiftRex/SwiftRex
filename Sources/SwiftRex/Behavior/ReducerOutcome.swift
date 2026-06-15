import CoreFP

/// The state-mutation half of a ``Consequence`` — either a concrete in-place mutation or a
/// provable no-op.
///
/// `ReducerOutcome` makes "this action does not touch state" a **named case** rather than an
/// indistinguishable identity closure. The ``Store`` uses that distinction to skip observer
/// notifications (`willChange`/`didChange`) entirely for actions that cannot change state —
/// pure routing, effect-only behaviors, `.doNothing` — so `ObservableObject`/`@Observable`
/// consumers don't re-render on actions that only produce effects.
///
/// - ``unchanged``: provably no mutation. The Store applies nothing and notifies no observer.
/// - ``mutation(_:)``: carries an `EndoMut<State>` to run in phase 2, bracketed by notifications.
///
/// ## Monoid
///
/// `ReducerOutcome` is a ``Monoid`` whose identity is ``unchanged``. ``combine(_:_:)`` short-circuits
/// the common case (one mutator among many `unchanged` siblings folds to a single `mutation`, no
/// nesting); two real mutations compose sequentially via `EndoMut`'s own `Monoid` (lhs then rhs).
///
/// - SeeAlso: ``Consequence``, ``EndoMut``
public enum ReducerOutcome<State: Sendable>: Sendable {
    /// No mutation — the Store applies nothing and fires no observer notifications.
    case unchanged
    /// A concrete in-place mutation to apply in phase 2, bracketed by `willChange`/`didChange`.
    case mutation(EndoMut<State>)

    /// Applies the mutation to `state` in place, or does nothing when ``unchanged``.
    ///
    /// Lets call sites that don't care about the notification-skipping distinction (tests, the
    /// `TestStore`) treat a `ReducerOutcome` exactly like a plain `EndoMut`.
    package func runEndoMut(_ state: inout State) {
        if case .mutation(let endoMut) = self { endoMut.runEndoMut(&state) }
    }

    /// Transforms the underlying `EndoMut` while preserving ``unchanged``.
    ///
    /// Used by the lift transforms to promote a child `EndoMut<State>` through an optic to a
    /// parent `EndoMut<NewState>` without losing the no-op information (`unchanged` stays
    /// `unchanged`, so the skip survives lifting).
    func map<NewState: Sendable>(
        _ f: @Sendable (EndoMut<State>) -> EndoMut<NewState>
    ) -> ReducerOutcome<NewState> {
        switch self {
        case .unchanged: .unchanged
        case .mutation(let endoMut): .mutation(f(endoMut))
        }
    }
}

// MARK: - Semigroup & Monoid

extension ReducerOutcome: Semigroup {
    /// Sequentially composes two outcomes: `lhs` then `rhs` on the same `inout State`.
    ///
    /// `unchanged` is absorbed (it is the identity), so combining a mutator with any number of
    /// `unchanged` siblings yields just the mutator — no wrapper, no allocation. Only when both
    /// sides mutate is an `EndoMut` composition built.
    public static func combine(_ lhs: ReducerOutcome, _ rhs: ReducerOutcome) -> ReducerOutcome {
        switch (lhs, rhs) {
        case (.unchanged, .unchanged): .unchanged
        case (.mutation(let endoMut), .unchanged), (.unchanged, .mutation(let endoMut)): .mutation(endoMut)
        case let (.mutation(lhs), .mutation(rhs)): .mutation(.combine(lhs, rhs))
        }
    }
}

extension ReducerOutcome: Monoid {
    /// The no-op outcome — the identity element for ``combine(_:_:)``.
    public static var identity: ReducerOutcome { .unchanged }
}
