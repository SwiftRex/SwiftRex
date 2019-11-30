#if canImport(Combine)
import SwiftRex

class EventReference: EventProtocol, Equatable {
    static func == (lhs: EventReference, rhs: EventReference) -> Bool {
        return lhs === rhs
    }
}
#endif
