import Foundation

struct GlobalState: Equatable, Encodable {
    var query: String?
    var lastSearch: AsyncResult<[Repository]> = .notLoaded
    var currentRepositories: [Repository] = []
    var nextPage: URL?
}

extension GlobalState: CustomDebugStringConvertible {
    var debugDescription: String {
        var response = ["query: \"\(query ?? "")\""]
        if currentRepositories.count > 0 {
            response.append("repositories: \(currentRepositories.count)")
        }

        switch lastSearch {
        case .notLoaded:
            response.append("status: not loaded")
        case .loading:
            response.append("status: loading")
        case .loaded:
            response.append("status: loaded")
            response.append("last page: \(nextPage == nil)")
        }

        return response.joined(separator: ", ")
    }
}
