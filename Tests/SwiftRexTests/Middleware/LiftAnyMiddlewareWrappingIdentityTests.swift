@testable import SwiftRex
import XCTest

class LiftAnyMiddlewareWrappingIdentityTests: XCTestCase {
    func testLiftInputActionOutputActionStateFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>().eraseToAnyMiddleware()
        let identityLifted = identityBefore.lift(
            inputAction: { (global: AppAction) in global.bar },
            outputAction: { bar in AppAction.bar(bar) },
            state: { (global: TestState) in global.name }
        )
        XCTAssertTrue(identityLifted.isIdentity)
        XCTAssertNotNil((identityLifted as Any) as? AnyMiddleware<AppAction, AppAction, TestState>)
    }

    func testLiftOutputActionStateFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>().eraseToAnyMiddleware()
        let identityLifted = identityBefore.lift(
            outputAction: { bar in AppAction.bar(bar) },
            state: { (global: TestState) in global.name }
        )
        XCTAssertTrue(identityLifted.isIdentity)
        XCTAssertNotNil((identityLifted as Any) as? AnyMiddleware<AppAction.Bar, AppAction, TestState>)
    }

    func testLiftInputActionStateFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>().eraseToAnyMiddleware()
        let identityLifted = identityBefore.lift(
            inputAction: { (global: AppAction) in global.bar },
            state: { (global: TestState) in global.name }
        )
        XCTAssertTrue(identityLifted.isIdentity)
        XCTAssertNotNil((identityLifted as Any) as? AnyMiddleware<AppAction, AppAction.Bar, TestState>)
    }

    func testLiftInputActionOutputActionFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>().eraseToAnyMiddleware()
        let identityLifted = identityBefore.lift(
            inputAction: { (global: AppAction) in global.bar },
            outputAction: { bar in AppAction.bar(bar) }
        )
        XCTAssertTrue(identityLifted.isIdentity)
        XCTAssertNotNil((identityLifted as Any) as? AnyMiddleware<AppAction, AppAction, String>)
    }

    func testLiftInputActionFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>().eraseToAnyMiddleware()
        let identityLifted = identityBefore.lift(
            inputAction: { (global: AppAction) in global.bar }
        )
        XCTAssertTrue(identityLifted.isIdentity)
        XCTAssertNotNil((identityLifted as Any) as? AnyMiddleware<AppAction, AppAction.Bar, String>)
    }

    func testLiftOutputActionFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>().eraseToAnyMiddleware()
        let identityLifted = identityBefore.lift(
            outputAction: { bar in AppAction.bar(bar) }
        )
        XCTAssertTrue(identityLifted.isIdentity)
        XCTAssertNotNil((identityLifted as Any) as? AnyMiddleware<AppAction.Bar, AppAction, String>)
    }

    func testLiftStateFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>().eraseToAnyMiddleware()
        let identityLifted = identityBefore.lift(
            state: { (global: TestState) in global.name }
        )
        XCTAssertTrue(identityLifted.isIdentity)
        XCTAssertNotNil((identityLifted as Any) as? AnyMiddleware<AppAction.Bar, AppAction.Bar, TestState>)
    }
}
