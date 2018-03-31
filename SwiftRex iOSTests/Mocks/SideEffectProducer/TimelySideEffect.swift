import RxSwift
@testable import SwiftRex
import XCTest

class TimelySideEffect: SideEffectProducer {
    private var name: String

    init(name: String) {
        self.name = name
    }

    func handle(event: Event, getState: @escaping () -> TestState) -> Observable<Action> {
        let actionChain: [Action]
        switch event {
        case _ as Event1:
            actionChain = [
                Action1(value: UUID(), name: "\(name)-a1")
            ]
        case _ as Event2:
            actionChain = [
                Action2(value: UUID(), name: "\(name)-a2"),
                Action3(value: UUID(), name: "\(name)-a3")
            ]
        case _ as Event3:
            actionChain = [
                Action3(value: UUID(), name: "\(name)-a3"),
                Action1(value: UUID(), name: "\(name)-a1"),
                Action2(value: UUID(), name: "\(name)-a2")
            ]
        default:
            return Observable.error(AnyError())
        }

        return Observable.create { observer in
            var actions = actionChain.makeIterator()

            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.schedule(deadline: DispatchTime.now() + 0.3, repeating: 0.3)

            let cancel = Disposables.create {
                timer.cancel()
            }

            timer.setEventHandler {
                if cancel.isDisposed {
                    return
                }

                guard let next = actions.next() else {
                    timer.cancel()
                    observer.onCompleted()
                    return
                }

                observer.on(.next(next))
            }

            timer.resume()

            return cancel
        }
    }
}
