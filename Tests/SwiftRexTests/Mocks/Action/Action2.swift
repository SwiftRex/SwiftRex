import RxSwift
@testable import SwiftRex
import XCTest

struct Action2: Action, Equatable {
    var value = UUID()
    var name = "a2"
}
