import RxSwift
@testable import SwiftRex
import XCTest

struct Event2: EventProtocol, Equatable {
    var value = UUID()
    var name = "e2"
}
