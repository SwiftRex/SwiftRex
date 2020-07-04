@testable import SwiftRex
import XCTest

class LiftIdentityMiddlewareTests: XCTestCase {
    func testLiftInputActionOutputActionStateFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>()
        let identityLifted = identityBefore.lift(
            inputActionMap: { (global: AppAction) in global.bar },
            outputActionMap: { bar in AppAction.bar(bar) },
            stateMap: { (global: TestState) in global.name }
        )
        XCTAssertEqual(identityLifted, IdentityMiddleware<AppAction, AppAction, TestState>())
    }

    func testLiftOutputActionStateFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>()
        let identityLifted = identityBefore.lift(
            outputActionMap: { bar in AppAction.bar(bar) },
            stateMap: { (global: TestState) in global.name }
        )
        XCTAssertEqual(identityLifted, IdentityMiddleware<AppAction.Bar, AppAction, TestState>())
    }

    func testLiftInputActionStateFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>()
        let identityLifted = identityBefore.lift(
            inputActionMap: { (global: AppAction) in global.bar },
            stateMap: { (global: TestState) in global.name }
        )
        XCTAssertEqual(identityLifted, IdentityMiddleware<AppAction, AppAction.Bar, TestState>())
    }

    func testLiftInputActionOutputActionFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>()
        let identityLifted = identityBefore.lift(
            inputActionMap: { (global: AppAction) in global.bar },
            outputActionMap: { bar in AppAction.bar(bar) }
        )
        XCTAssertEqual(identityLifted, IdentityMiddleware<AppAction, AppAction, String>())
    }

    func testLiftInputActionFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>()
        let identityLifted = identityBefore.lift(
            inputActionMap: { (global: AppAction) in global.bar }
        )
        XCTAssertEqual(identityLifted, IdentityMiddleware<AppAction, AppAction.Bar, String>())
    }

    func testLiftOutputActionFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>()
        let identityLifted = identityBefore.lift(
            outputActionMap: { bar in AppAction.bar(bar) }
        )
        XCTAssertEqual(identityLifted, IdentityMiddleware<AppAction.Bar, AppAction, String>())
    }

    func testLiftStateFromIdentity() {
        let identityBefore = IdentityMiddleware<AppAction.Bar, AppAction.Bar, String>()
        let identityLifted = identityBefore.lift(
            stateMap: { (global: TestState) in global.name }
        )
        XCTAssertEqual(identityLifted, IdentityMiddleware<AppAction.Bar, AppAction.Bar, TestState>())
    }
}
