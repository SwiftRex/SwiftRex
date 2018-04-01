import RxSwift
import SwiftRex

final class CounterService: SideEffectProducer {
    var event: CounterEvent

    init(event: CounterEvent) {
        self.event = event
    }

    func execute(getState: @escaping () -> GlobalState) -> Observable<Action> {
        switch event {
        case .increaseRequest: return increase().map { $0 as Action }
        case .decreaseRequest: return decrease().map { $0 as Action }
        }
    }

    func increase() -> Observable<CounterAction> {
        return Observable.create { observer in
            print("Subscribed")

            // This is a cold observable, that means, subscribing it
            // causes a side effect, which could be a network call
            // or a disk operation for example.
            observer.onNext(CounterAction.setLoading(true))

            let cancel = Disposables.create {
                print("Disposed")
            }

            print("Start something slow")
            DispatchQueue
                .global()
                .asyncAfter(deadline: .now() + 0.5) {
                    print("Something slow has finished")
                    guard !cancel.isDisposed else {
                        print("... but oops, was cancelled")
                        return
                    }

                    observer.onNext(CounterAction.increaseValue)
                    observer.onNext(CounterAction.setLoading(false))
                    // Done with this side effect operation!
                    // Let's complete it and allow it to be disposed
                    observer.onCompleted()
            }

            return cancel
        }
    }

    func decrease() -> Observable<CounterAction> {
        return Observable.create { observer in
            print("Subscribed")

            // This is a cold observable, that means, subscribing it
            // causes a side effect, which could be a network call
            // or a disk operation for example.
            observer.onNext(CounterAction.setLoading(true))

            let cancel = Disposables.create {
                print("Disposed")
            }

            print("Start something slow")
            DispatchQueue
                .global()
                .asyncAfter(deadline: .now() + 0.5) {
                    print("Something slow has finished")
                    guard !cancel.isDisposed else {
                        print("... but oops, was cancelled")
                        return
                    }

                    observer.onNext(CounterAction.decreaseValue)
                    observer.onNext(CounterAction.setLoading(false))
                    // Done with this side effect operation!
                    // Let's complete it and allow it to be disposed
                    observer.onCompleted()
            }

            return cancel
        }
    }
}
