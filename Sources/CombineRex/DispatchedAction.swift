import Foundation
import SwiftRex

public struct DispatchedAction<Action> {
    public let action: Action
    public let dispatcher: ActionSource

    public init(_ action: Action, dispatcher: ActionSource = .here()) {
        self.action = action
        self.dispatcher = dispatcher
    }
}

extension DispatchedAction {
    public func map<NewAction>(_ transform: (Action) -> NewAction) -> DispatchedAction<NewAction> {
        DispatchedAction<NewAction>(transform(action), dispatcher: dispatcher)
    }
}
