import Foundation
import SwiftRex

class TimelySideEffect: SideEffectProducer {
    private var event: EventProtocol
    private var name: String

    init(event: EventProtocol, name: String) {
        self.event = event
        self.name = name
    }

    func execute(getState: @escaping () -> TestState) -> FailableObservableSignalProducer<ActionProtocol> {
        let actions: [ActionProtocol]
        switch event {
        case _ as Event1:
            actions = [
                Action1(value: UUID(), name: "\(name)-a1")
            ]
        case _ as Event2:
            actions = [
                Action2(value: UUID(), name: "\(name)-a2"),
                Action3(value: UUID(), name: "\(name)-a3")
            ]
        case _ as Event3:
            actions = [
                Action3(value: UUID(), name: "\(name)-a3"),
                Action1(value: UUID(), name: "\(name)-a1"),
                Action2(value: UUID(), name: "\(name)-a2")
            ]
        default:
            return observable(of: ActionProtocol.self, error: SomeError())
        }

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: DispatchTime.now() + 0.3, repeating: 0.3)

        return timelyObservableOf(actions: actions, timer: timer)
    }
}

#if canImport(RxSwift)
import RxSwift

private func timelyObservableOf(actions: [ActionProtocol],
                                timer: DispatchSourceTimer) -> FailableObservableSignalProducer<ActionProtocol> {
    var actions = actions.makeIterator()
    return Observable.create { observer in
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
#endif

#if canImport(ReactiveSwift)
import struct ReactiveSwift.SignalProducer

private func timelyObservableOf(actions: [ActionProtocol],
                                timer: DispatchSourceTimer) -> FailableObservableSignalProducer<ActionProtocol> {
    var actions = actions.makeIterator()
    return .init { observer, dispose in
        dispose.observeEnded {
            timer.cancel()
        }

        timer.setEventHandler {
            if dispose.hasEnded {
                return
            }

            guard let next = actions.next() else {
                timer.cancel()
                observer.sendCompleted()
                return
            }

            observer.send(value: next)
        }

        timer.resume()
    }
}
#endif
