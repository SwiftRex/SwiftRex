import SwiftRex

class EventReference: Event, Equatable {
    static func == (lhs: EventReference, rhs: EventReference) -> Bool {
        return lhs === rhs
    }
}
