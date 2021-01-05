import Foundation

/// A predicate that determines if a state change should notify subscribers or not, by comparing previous and new states and returning a Bool true in
/// case it should emit it, or false in case it should not emit it.
/// It comes with some standard options like `.always`, `.never`, `.when(old, new) -> Bool` and, for `Equatable` structures, `.whenDifferent`.
public enum ShouldEmitValue<StateType> {
    // private let evaluate: (StateType, StateType) -> Bool

    /// It will always emit changes, regardless of previous and new state
    case always

    /// It will never emit changes, regardless of previous and new state
    case never

    /// It's a custom-defined predicate, you'll be given old and new state, and must return a Bool indicating what you've decided from that change,
    /// being `true` when you want this change to be notified, or `false` when you want it to be ignored.
    case when((StateType, StateType) -> Bool)

    /// Evaluates the predicate and returns `true` in case this should be emitted, or `false` in case this change should be ignored
    public func shouldEmit(previous: StateType, new: StateType) -> Bool {
        switch self {
        case .always: return true
        case .never: return false
        case let .when(evaluate): return evaluate(previous, new)
        }
    }

    /// Evaluates the predicate and returns `true` in case this should be ignored, or `false` in case this change should be emitted. It's the exact
    /// inversion of `shouldEmit` and useful for operator `.removeDuplicates` that some Reactive libraries offer.
    public func shouldRemove(previous: StateType, new: StateType) -> Bool {
        !shouldEmit(previous: previous, new: new)
    }
}

extension ShouldEmitValue where StateType: Equatable {
    /// For `Equatable` structures, `.whenDifferent` will run `==` operator between old and new state, and notify when they are different, or ignore
    /// when they are equal.
    public static var whenDifferent: ShouldEmitValue<StateType> { .when(!=) }
}
