import SwiftRex

enum RepositorySearchEvent: EventProtocol {
    case changedQuery(String?)
    case approachingEndOfCurrentPage
}
