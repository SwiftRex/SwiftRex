import Foundation
import RxSwift

public protocol Cancelable {
    func cancel()
}

extension URLSessionTask: Cancelable { }

public struct CancelableBox: Cancelable {
    var cancelFunction: () -> Void

    init(cancelFunction: @escaping () -> Void) {
        self.cancelFunction = cancelFunction
    }

    public func cancel() {
        cancelFunction()
    }
}

public class ObservableCancelable: ObservableType, Cancelable {
    public typealias E = Bool
    private let cancelled = BehaviorSubject<Bool>(value: false)

    public func subscribe<O>(_ observer: O) -> Disposable where O: ObserverType, ObservableCancelable.E == O.E {
        return cancelled.subscribe(observer)
    }

    public func cancel() {
        cancelled.onNext(true)
    }
}
