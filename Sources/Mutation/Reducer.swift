// sourcery: AutoMockable
// sourcery: TypeErase = StateType
public protocol Reducer {
    associatedtype StateType
    func reduce(_ currentState: StateType, action: Action) -> StateType
}
