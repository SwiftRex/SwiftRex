import Foundation
import RxSwift
import SwiftRex

class GlobalStore: StoreBase<GlobalState>, GlobalStateProvider {
    init() {
        super.init(initialState: GlobalState(),
                   reducer: counterReducer,
                   middleware: ServicesMiddleware())
    }
}
