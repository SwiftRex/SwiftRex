// sourcery: TypeErase = StateType
public protocol SideEffectFactory {
    associatedtype StateType
    func evaluate(event: Event, getState: @escaping GetState<StateType>) -> Observable<Action>
}
