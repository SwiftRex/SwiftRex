/// Controls when the Store notifies observers after a state mutation.
///
/// Keeping deduplication in-house avoids relying on downstream `.removeDuplicates()` operators,
/// which have had correctness issues in Combine, and avoids forcing `Equatable` on `State`.
public enum ShouldEmitValue<State> {
    /// Always notify observers, even when the new state is identical.
    case always

    /// Never notify observers. Useful for testing or derived projections.
    case never

    /// Notify observers only when the predicate returns `true`.
    ///
    /// - Parameter predicate: receives `(old, new)` and returns whether observers should be notified.
    case when((State, State) -> Bool)
}

extension ShouldEmitValue {
    func shouldEmit(old: State, new: State) -> Bool {
        switch self {
        case .always: true
        case .never: false
        case let .when(predicate): predicate(old, new)
        }
    }
}

extension ShouldEmitValue where State: Equatable {
    /// Only emit when the new state differs from the old state.
    public static func whenDifferent() -> ShouldEmitValue<State> {
        .when { $0 != $1 }
    }
}

extension ShouldEmitValue {
    /// Only emit when the new state differs from the old state, in a specific path
    public static func whenDifferent<B: Equatable>(_ path: @escaping (State) -> B) -> ShouldEmitValue<State> {
        .when { old, new in path(old) != path(new) }
    }
}
