#if canImport(Combine)
import Combine

public class DisposeBag {
    var cancelables = [AnyCancellable]()

    deinit {
        cancelables.forEach { $0.cancel() }
    }
}

extension Cancellable {
    public func disposed(by disposeBag: DisposeBag) {
        disposeBag.cancelables.append(AnyCancellable(self))
    }
}

public typealias ObservableSignal<T> = PassthroughSubject<T, Never>
public typealias FailableObservableSignal<T> = PassthroughSubject<T, Error>
public typealias ObservableSignalProducer<T> = PassthroughSubject<T, Never>
public typealias FailableObservableSignalProducer<T> = PassthroughSubject<T, Error>
public typealias SubscriptionOwner = DisposeBag
public typealias ObservableProperty = Publisher
public typealias ReactiveProperty<T> = CurrentValueSubject<T, Never>

extension StateProvider {
    /// The elements in the ObservableType sequence, which is expected to be the `StateType` (the app global state)
    public typealias StateType = Output
}
#endif
