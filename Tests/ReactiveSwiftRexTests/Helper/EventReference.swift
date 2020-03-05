import SwiftRex

class EventReference: EventProtocol, Equatable {
    static func == (lhs: EventReference, rhs: EventReference) -> Bool {
        lhs === rhs
    }
}
