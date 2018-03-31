import SwiftRex

class EventAndActionReference: Event, Action, Equatable {
    static func == (lhs: EventAndActionReference, rhs: EventAndActionReference) -> Bool {
        return lhs === rhs
    }
}
