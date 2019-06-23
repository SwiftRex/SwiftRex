import SwiftRex

class EventAndActionReference: EventProtocol, ActionProtocol, Equatable {
    static func == (lhs: EventAndActionReference, rhs: EventAndActionReference) -> Bool {
        return lhs === rhs
    }
}
