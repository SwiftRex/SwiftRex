// sourcery: TypeErase = StateType
public protocol SideEffectFactory {
    associatedtype StateType
    func evaluate(event: Event, getState: @escaping () -> StateType) -> Observable<Action>
}
