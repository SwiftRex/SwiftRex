import RxSwift
@testable import SwiftRex
import XCTest

struct Event1: Event, Equatable {
    var value = UUID()
    var name = "e1"
}
