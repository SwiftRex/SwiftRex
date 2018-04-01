import RxSwift
@testable import SwiftRex
import XCTest

struct Action3: Action, Equatable {
    var value = UUID()
    var name = "a3"
}
