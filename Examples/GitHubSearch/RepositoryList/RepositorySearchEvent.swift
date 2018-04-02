import SwiftRex

enum RepositorySearchEvent: Event {
    case changedQuery(String?)
    case approachingEndOfCurrentPage
}
