import Foundation

public struct ShouldEmitValue<StateType> {
    public let evaluate: (StateType, StateType) -> Bool

    private init(evaluate: @escaping (StateType, StateType) -> Bool) {
        self.evaluate = evaluate
    }
}

extension ShouldEmitValue {
    public static var always: ShouldEmitValue<StateType> { .init(evaluate: { _, _ in true }) }
    public static var never: ShouldEmitValue<StateType> { .init(evaluate: { _, _ in false }) }
    public static var when: (@escaping (StateType, StateType) -> Bool) -> ShouldEmitValue<StateType> {
        ShouldEmitValue<StateType>.init
    }
}

extension ShouldEmitValue where StateType: Equatable {
    public static var whenDifferent: ShouldEmitValue<StateType> { .init(evaluate: !=) }
}
