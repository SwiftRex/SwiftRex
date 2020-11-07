import Foundation
import RxSwift

/// Fire And Forget is an observable for when you don't care about the output of certain async operation. It's important to notice that this operation
/// can't fail. If you want to also ignore the failure, then you can catchErrors and return nil in the proper init.
/// It may complete successfully when task is done.
public struct FireAndForget<IgnoringOutput>: ObservableType {
    /// Output type we are ignoring. It matches the FireAndForget generic parameter, so we can ignore anything we want.
    public typealias Element = IgnoringOutput

    private let innerObservable: Observable<IgnoringOutput>

    /// Init a FireAndForget observable by providing a closure with the operation to execute and ignore the output.
    /// - Parameter operation: any operation you want to run async and ignore the result
    public init(_ operation: @escaping () -> Void) {
        self.init(Observable<Void>.empty().do(onSubscribe: { operation() }))
    }

    /// Init a FireAndForget observable by providing an upstream that never fails so we can simply ignore its output
    /// - Parameter upstream: any observable that never fails
    public init<O: ObservableType>(_ upstream: O) {
        innerObservable = upstream
            .ignoreElements()
            .asObservable()
            .map(absurd)
    }

    /// Init a FireAndForget observable by providing an upstream that could fail, as well as a catchErrors function to ensure that FireAndForget can't
    /// itself fail. You can safely return nil from catchErrors. Otherwise outputs sent from catch errors will NOT be ignored, only those from the
    /// happy path.
    public init<O: ObservableType>(_ upstream: O, catchErrors: @escaping (Error) -> IgnoringOutput?) {
        innerObservable = upstream
            .ignoreElements()
            .asObservable()
            .map(absurd)
            .catchError { error -> Observable<IgnoringOutput?> in
                .just(catchErrors(error))
            }
            .compactMap { $0 }
    }

    public func subscribe<Observer>(_ observer: Observer) -> Disposable where Observer: ObserverType, Self.Element == Observer.Element {
        innerObservable.subscribe(observer)
    }
}

private func absurd<T>(_ never: Never) -> T { }
