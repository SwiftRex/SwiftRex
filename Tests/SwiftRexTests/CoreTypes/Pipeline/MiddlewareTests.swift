import Foundation
@testable import SwiftRex
import XCTest

class MiddlewareTests: XCTestCase {
    func testEmptyHandleAction() {
        let shouldCallNext1 = expectation(description: "next middleware should have been called on first event")
        let shouldCallNext2 = expectation(description: "next middleware should have been called on second event")

        class SomeMiddleware: Middleware {
            lazy var context: (() -> MiddlewareContext<AppAction, TestState>) = { {
                    .init(
                        onAction: { _ in fatalError("on action was not supposed to be called") },
                        getState: { fatalError("get state was not supposed to be called") }
                    )
                }
            }()
        }

        let sut = SomeMiddleware()
        sut.handle(action: .bar(.bravo), next: { shouldCallNext1.fulfill() })
        sut.handle(action: .bar(.charlie), next: { shouldCallNext2.fulfill() })
        wait(for: [shouldCallNext1, shouldCallNext2], timeout: 0.1, enforceOrder: true)
    }
}
