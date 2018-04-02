import SwiftRex

struct RepositorySearchReducer: Reducer {
    func reduce(_ currentState: GlobalState, action: Action) -> GlobalState {
        guard let action = action as? RepositorySearchAction else { return currentState }

        var state = currentState

        switch action {
        case let .setQuery(query):
            state.query = query
        case .startedSearch(let task):
            state.lastSearch = .loading(task: task, lastResult: state.lastSearch.possibleResult())
        case .gotFirstPage(let result, let nextPage):
            state.lastSearch = .loaded(.success(result))
            state.currentRepositories = result
            state.nextPage = nextPage
        case .gotNextPage(let result, let nextPage):
            state.lastSearch = .loaded(.success(result))
            state.currentRepositories += result
            state.nextPage = nextPage
        case .gotError(let error):
            state.lastSearch = .loaded(.failure(error))
            print(action)
        }

        return state
    }
}
