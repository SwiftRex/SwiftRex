import RxSwift
import SwiftRex

final class ServicesMiddleware: SideEffectMiddleware {
    typealias StateType = GlobalState

    var actionHandler: ActionHandler?
    var allowEventToPropagate = false
    var disposeBag = DisposeBag()

    func sideEffect(for event: SwiftRex.Event) -> AnySideEffectProducer<GlobalState>? {
        switch event {
        case let event as CounterEvent:
            return AnySideEffectProducer(CounterService(event: event))
        default: return nil
        }
    }
}
