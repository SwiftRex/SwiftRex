import Foundation
import RxSwift
import UIKit

struct RepositorySearchViewModel {
    let query: String?
    let repositories: [String]

    init(from state: GlobalState) {
        query = state.query
        repositories = state.currentRepositories.map { $0.name }
    }

    private init() {
        self.query = nil
        self.repositories = []
    }

    static var `default`: RepositorySearchViewModel {
        return RepositorySearchViewModel()
    }
}

struct RepositorySearchViewInput {
    let queryText: Observable<String?>
    let scrollOffset: Observable<CGPoint>
    let frame: Observable<CGRect>
    let contentSize: Observable<CGSize>
}

typealias RepositorySearchViewOutput = Observable<RepositorySearchViewModel>
