#if canImport(Combine)
import SwiftRex

class ActionReference: ActionProtocol, Equatable {
    static func == (lhs: ActionReference, rhs: ActionReference) -> Bool {
        return lhs === rhs
    }
}
#endif
