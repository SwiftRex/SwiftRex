import Foundation
import SwiftRex

struct Event1: EventProtocol, Equatable {
    var value = UUID()
    var name = "e1"
}
