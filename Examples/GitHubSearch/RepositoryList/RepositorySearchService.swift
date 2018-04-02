import RxCocoa
import RxSwift
import SwiftRex

final class RepositorySearchService: SideEffectProducer {
    var event: RepositorySearchEvent
    private let service = GitHubSearchRepositoriesAPI.sharedAPI

    init(event: RepositorySearchEvent) {
        self.event = event
    }

    func execute(getState: @escaping () -> GlobalState) -> Observable<Action> {
        let state = getState()

        switch event {
        case .changedQuery(let query):
            return loadFirstPage(query, state).map { $0 as Action }
        case .approachingEndOfCurrentPage:
            return loadNextPage(state).map { $0 as Action }
        }
    }

    func loadFirstPage(_ query: String?, _ state: GlobalState) -> Observable<RepositorySearchAction> {
        state.lastSearch.possibleTask()?.cancel()

        let setQuery = Observable.just(RepositorySearchAction.setQuery(query))
        guard let pageUrl = url(for: query, page: 1) else { return setQuery }

        return Observable.concat(
            setQuery,
            loadPage(pageUrl: pageUrl,
                     transform: { $0.map(RepositorySearchAction.gotFirstPage,
                                         RepositorySearchAction.gotError) })
            )
    }

    func loadNextPage(_ state: GlobalState) -> Observable<RepositorySearchAction> {
        guard state.lastSearch.possibleTask() == nil,
            let pageUrl = state.nextPage else {
                return .empty()
        }

        return loadPage(pageUrl: pageUrl,
                        transform: { $0.map(RepositorySearchAction.gotNextPage,
                                            RepositorySearchAction.gotError) })
    }

    private func loadPage(pageUrl: URL, transform: @escaping (Result<(repositories: [Repository], nextURL: URL?)>) throws -> RepositorySearchAction) -> Observable<RepositorySearchAction> {
        let task = ObservableCancelable()

        return Observable.concat(
            .just(RepositorySearchAction.startedSearch(task: task)),

            service
                .loadSearchURL(pageUrl)
                .takeUntil(task.filter { $0 })
                .catchError { .just(.failure($0)) }
                .map(transform)
        )
    }

    private func url(for query: String?, page: Int) -> URL? {
        guard let query = query, !query.isEmpty else { return nil }
        return URL(string: "https://api.github.com/search/repositories?q=\(query)&page=\(page)")
    }
}
