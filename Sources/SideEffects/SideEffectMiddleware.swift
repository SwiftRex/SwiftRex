import RxSwift

struct SideEffectError: Action {
    let originalEvent: Event
    let error: Error
}

public protocol SideEffectMiddleware: Middleware {
    var allowEventToPropagate: Bool { get }
    var disposeBag: DisposeBag { get }
    func sideEffect(for event: Event) -> AnySideEffectProducer<StateType>?
}

extension SideEffectMiddleware {
    public func handle(event: Event, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>) {
        guard let sideEffect = sideEffect(for: event) else {
            next(event, getState)
            return
        }

        sideEffect.execute(getState: getState).subscribe(
            onNext: { [weak self] action in
                self?.actionHandler?.trigger(action)
            },
            onError: { [weak self] error in
                let action = SideEffectError(originalEvent: event, error: error)
                self?.actionHandler?.trigger(action)
            }
        ).disposed(by: disposeBag)

        guard allowEventToPropagate else { return }

        next(event, getState)
    }

    public func handle(action: Action, getState: @escaping GetState<StateType>, next: @escaping NextActionHandler<StateType>) {
        next(action, getState)
    }
}
