import RxSwift
@testable import SwiftRex
import XCTest

struct Action1: ActionProtocol, Equatable {
    var value = UUID()
    var name = "a1"
}
