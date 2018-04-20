import RxSwift
@testable import SwiftRex
import XCTest

struct Event1: EventProtocol, Equatable {
    var value = UUID()
    var name = "e1"
}
