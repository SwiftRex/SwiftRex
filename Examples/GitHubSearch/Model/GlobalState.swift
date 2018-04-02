import Foundation

struct GlobalState: Equatable {
    var query: String?
    var lastSearch: AsyncResult<[Repository]> = .notLoaded
    var currentRepositories: [Repository] = []
    var nextPage: URL?
}
