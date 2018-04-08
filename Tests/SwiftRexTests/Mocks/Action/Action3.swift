import RxSwift
@testable import SwiftRex
import XCTest

struct Action3: ActionProtocol, Equatable {
    var value = UUID()
    var name = "a3"
}
