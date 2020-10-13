import Foundation
import SwiftRex

public struct DispatchedAction<Action> {
    public let action: Action
    public let dispatcher: ActionSource

    public init(_ action: Action, dispatcher: ActionSource) {
        self.action = action
        self.dispatcher = dispatcher
    }

    public init(_ action: Action, file: String = #file, function: String = #function, line: UInt = #line, info: String? = nil) {
        self.init(
            action,
            dispatcher: ActionSource(file: file, function: function, line: line, info: info)
        )
    }
}

extension DispatchedAction {
    public func map<NewAction>(_ transform: (Action) -> NewAction) -> DispatchedAction<NewAction> {
        DispatchedAction<NewAction>(transform(action), dispatcher: dispatcher)
    }
}
