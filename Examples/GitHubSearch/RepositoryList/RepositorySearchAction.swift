import SwiftRex

enum RepositorySearchAction: Action {
    case setQuery(String?)
    case startedSearch(task: Cancelable)
    case gotFirstPage([Repository], nextPage: URL?)
    case gotNextPage([Repository], nextPage: URL?)
    case gotError(Error)
}
