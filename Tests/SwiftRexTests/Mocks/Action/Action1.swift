import RxSwift
@testable import SwiftRex
import XCTest

struct Action1: Action, Equatable {
    var value = UUID()
    var name = "a1"
}
