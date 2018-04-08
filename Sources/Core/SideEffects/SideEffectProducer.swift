import RxSwift

// sourcery: AutoMockable
// sourcery: TypeErase = StateType
public protocol SideEffectProducer {
    associatedtype StateType
    func execute(getState: @escaping GetState<StateType>) -> Observable<ActionProtocol>
}
