import RxSwift
@testable import SwiftRex
import XCTest

struct Action2: ActionProtocol, Equatable {
    var value = UUID()
    var name = "a2"
}
