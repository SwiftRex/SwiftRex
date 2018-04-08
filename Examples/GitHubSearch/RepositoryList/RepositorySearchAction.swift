import SwiftRex

enum RepositorySearchAction: ActionProtocol {
    case setQuery(String?)
    case startedSearch(task: Cancelable)
    case gotFirstPage([Repository], nextPage: URL?)
    case gotNextPage([Repository], nextPage: URL?)
    case gotError(Error)
}
