import SwiftRex

class ActionReference: Action, Equatable {
    static func == (lhs: ActionReference, rhs: ActionReference) -> Bool {
        return lhs === rhs
    }
}
