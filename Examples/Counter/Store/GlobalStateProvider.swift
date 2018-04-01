import RxSwift

protocol GlobalStateProvider {
    typealias E = GlobalState

    func subscribe<O>(_ observer: O) -> Disposable where O: ObserverType, Self.E == O.E
    func subscribe(_ on: @escaping (Event<E>) -> Void) -> Disposable
    func subscribe(onNext: ((E) -> Void)?, onError: ((Swift.Error) -> Void)?, onCompleted: (() -> Void)?, onDisposed: (() -> Void)?) -> Disposable
    func distinctUntilChanged() -> RxSwift.Observable<Self.E>
}
