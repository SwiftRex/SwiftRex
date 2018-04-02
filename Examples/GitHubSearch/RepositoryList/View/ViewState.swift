struct ViewState {
    let query: String?
    let repositories: [String]

    init(from state: GlobalState) {
        query = state.query
        repositories = state.currentRepositories.map { $0.name }
    }
}
