import SwiftRex

class ActionReference: ActionMock, Equatable {
    static func == (lhs: ActionReference, rhs: ActionReference) -> Bool {
        return lhs === rhs
    }
}
