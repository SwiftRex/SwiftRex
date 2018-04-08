import RxSwift
import SwiftRex

protocol RepositorySearchPresenterProtocol {
    func bind(input: RepositorySearchViewInput) -> RepositorySearchViewOutput
}

class RepositorySearchPresenter: RepositorySearchPresenterProtocol {
    private let stateProvider: GlobalStateProvider
    private let eventHandler: EventHandler
    private var inputDisposeBag: DisposeBag?

    func bind(input: RepositorySearchViewInput) -> RepositorySearchViewOutput {
        inputDisposeBag = DisposeBag()

        input
            .queryText
            .throttle(0.3, scheduler: MainScheduler.instance)
            .map(RepositorySearchEvent.changedQuery)
            .subscribe(onNext: eventHandler.dispatch)
            .disposed(by: inputDisposeBag!)

        Observable.combineLatest(
            input.scrollOffset,
            input.frame,
            input.contentSize)
            .map { offset, frame, contentSize in
                guard frame.height > 0, contentSize.height > 0 else { return false }
                return offset.y + frame.height >= contentSize.height - 100
            }
            .distinctUntilChanged()
            .filter { $0 }
            .map { _ in RepositorySearchEvent.approachingEndOfCurrentPage }
            .subscribe(onNext: eventHandler.dispatch)
            .disposed(by: inputDisposeBag!)

        return stateProvider
            .share(replay: 1, scope: .forever)
            .distinctUntilChanged()
            .map(RepositorySearchViewModel.init)
    }

    init(stateProvider: GlobalStateProvider, eventHandler: EventHandler) {
        self.stateProvider = stateProvider
        self.eventHandler = eventHandler
    }
}
