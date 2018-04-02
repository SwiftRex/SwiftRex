import Foundation
import RxSwift

protocol Cancelable {
    func cancel()
}

extension URLSessionTask: Cancelable { }

struct CancelableBox: Cancelable {
    var cancelFunction: () -> Void

    init(cancelFunction: @escaping () -> Void) {
        self.cancelFunction = cancelFunction
    }

    func cancel() {
        cancelFunction()
    }
}

class ObservableCancelable: ObservableType, Cancelable {
    typealias E = Bool
    private let cancelled = BehaviorSubject<Bool>(value: false)

    func subscribe<O>(_ observer: O) -> Disposable where O: ObserverType, ObservableCancelable.E == O.E {
        return cancelled.subscribe(observer)
    }

    func cancel() {
        cancelled.onNext(true)
    }
}
