import RxSwift
@testable import SwiftRex
import XCTest

struct Event2: Event, Equatable {
    var value = UUID()
    var name = "e2"
}
