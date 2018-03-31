import RxSwift

// sourcery: AutoMockable
// sourcery: TypeErase = StateType
public protocol SideEffectProducer {
    associatedtype StateType
    func handle(event: Event, getState: @escaping GetState<StateType>) -> Observable<Action>
}
