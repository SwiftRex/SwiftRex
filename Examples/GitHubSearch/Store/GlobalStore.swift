import Foundation
import RxSwift
import SwiftRex
import SwiftRexMonitorMiddleware

class GlobalStore: StoreBase<GlobalState>, GlobalStateProvider {
    init() {
        let logger = LoggerMiddleware(stateTransformer: stateTransformer,
                                      actionTransformer: actionTransformer)

        let monitor: MonitorMiddleware<GlobalState> = MonitorMiddleware()

        let services = ServicesMiddleware()

        super.init(initialState: GlobalState(),
                   reducer: repositorySearchReducer,
                   middleware: logger >>> monitor >>> services)
    }
}

private func stateTransformer(state: GlobalState) -> String {
    return state.debugDescription
}

private func actionTransformer(action: ActionProtocol) -> String {
    let actionDescription = "\(action)"

    return actionDescription.count < 50
        ? actionDescription
        : actionDescription.index(of: "(").map { String(actionDescription.prefix(upTo: $0)) }
        ?? actionDescription
}
