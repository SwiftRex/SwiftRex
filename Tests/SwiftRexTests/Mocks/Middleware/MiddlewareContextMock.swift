import Foundation
import SwiftRex

class MiddlewareContextMock<ActionType, StateType> {
    lazy var value: MiddlewareContext<ActionType, StateType> = {
        .init(
            onAction: { action in
                self.onActionParameters.append(action)
                self.onActionCount += 1
                self.onActionClosure?(action)
            },
            getState: {
                self.getStateCount += 1
                return self.state
            }
        )
    }()

    var state: StateType!
    var getStateCount: Int = 0
    var onActionClosure: ((ActionType) -> Void)?
    var onActionCount: Int = 0
    var onActionParameters: [ActionType] = []
}
