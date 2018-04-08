import RxSwift
@testable import SwiftRex
import XCTest

struct Event3: EventProtocol, Equatable {
    var value = UUID()
    var name = "e3"
}
