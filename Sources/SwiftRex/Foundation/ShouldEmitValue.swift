import Foundation

/// A predicate that determines if a state change should notify subscribers or not, by comparing previous and new states and returning a Bool true in
/// case it should emit it, or false in case it should not emit it.
/// It comes with some standard options like `.always`, `.never`, `.when(old, new) -> Bool` and, for `Equatable` structures, `.whenDifferent`.
public struct ShouldEmitValue<StateType> {
    private let evaluate: (StateType, StateType) -> Bool

    private init(evaluate: @escaping (StateType, StateType) -> Bool) {
        self.evaluate = evaluate
    }

    /// Evaluates the predicate and returns `true` in case this should be emitted, or `false` in case this change should be ignored
    public func shouldEmit(previous: StateType, new: StateType) -> Bool {
        evaluate(previous, new)
    }

    /// Evaluates the predicate and returns `true` in case this should be ignored, or `false` in case this change should be emitted. It's the exact
    /// inversion of `shouldEmit` and useful for operator `.removeDuplicates` that some Reactive libraries offer.
    public func shouldRemove(previous: StateType, new: StateType) -> Bool {
        !evaluate(previous, new)
    }
}

extension ShouldEmitValue {
    /// It will always emit changes, regardless of previous and new state
    public static var always: ShouldEmitValue<StateType> { .init(evaluate: { _, _ in true }) }

    /// It will never emit changes, regardless of previous and new state
    public static var never: ShouldEmitValue<StateType> { .init(evaluate: { _, _ in false }) }

    /// It's a custom-defined predicate, you'll be given old and new state, and must return a Bool indicating what you've decided from that change,
    /// being `true` when you want this change to be notified, or `false` when you want it to be ignored.
    public static var when: (@escaping (StateType, StateType) -> Bool) -> ShouldEmitValue<StateType> {
        ShouldEmitValue<StateType>.init
    }
}

extension ShouldEmitValue where StateType: Equatable {
    /// For `Equatable` structures, `.whenDifferent` will run `==` operator between old and new state, and notify when they are different, or ignore
    /// when they are equal.
    public static var whenDifferent: ShouldEmitValue<StateType> { .init(evaluate: !=) }
}
