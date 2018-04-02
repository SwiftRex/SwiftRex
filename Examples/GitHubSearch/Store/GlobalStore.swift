import Foundation
import RxSwift
import SwiftRex

class GlobalStore: StoreBase<GlobalState>, GlobalStateProvider {
    init() {
        let logger = LoggerMiddleware(stateTransformer: stateTransformer,
                                      actionTransformer: actionTransformer)
        let services = ServicesMiddleware()

        super.init(initialState: GlobalState(),
                   reducer: RepositorySearchReducer(),
                   middleware: logger >>> services)
    }
}

private func stateTransformer(state: GlobalState) -> String {
    return state.debugDescription
}

private func actionTransformer(action: Action) -> String {
    let actionDescription = "\(action)"

    return actionDescription.count < 50
        ? actionDescription
        : actionDescription.index(of: "(").map { String(actionDescription.prefix(upTo: $0)) }
        ?? actionDescription
}
