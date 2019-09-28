import Foundation
@testable import SwiftRex
import XCTest

class TypeErasureTests: XCTestCase {
    #if !SWIFT_PACKAGE
    func testMiddlewareBaseInitThrows() {
        XCTAssertThrowsError({ _ = _AnyMiddlewareBase<TestState>() })
    }

    func testMiddlewareBaseHandleEventThrows() {
        let sut = MiddlewareAbstract<TestState>()
        XCTAssertThrowsError({
            sut.handle(event: Event1(), getState: { TestState() }, next: { _, _ in })
        })
    }

    func testMiddlewareBaseHandleActionThrows() {
        let sut = MiddlewareAbstract<TestState>()
        XCTAssertThrowsError({
            sut.handle(action: Action1(), getState: { TestState() }, next: { _, _ in })
        })
    }

    func testMiddlewareBaseHandlerGetThrows() {
        let sut = MiddlewareAbstract<TestState>()
        XCTAssertThrowsError({
            _ = sut.context
        })
    }

    func testMiddlewareBaseHandlerSetThrows() {
        let sut = MiddlewareAbstract<TestState>()
        XCTAssertThrowsError({
            sut.context = {
                .init(actionHandler: ActionHandler(), eventHandler: EventHandler())
            }
        })
    }
    #endif
}

class MiddlewareAbstract<T>: _AnyMiddlewareBase<T> {
}
