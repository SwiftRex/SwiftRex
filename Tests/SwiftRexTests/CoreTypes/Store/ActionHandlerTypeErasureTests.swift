import Foundation
@testable import SwiftRex
import XCTest

class ActionHandlerTypeErasureTests: XCTestCase {
    func testActionHandlerMockErased() {
        let mock = ActionHandlerMock<String>()
        let sut = mock.eraseToAnyActionHandler()
        XCTAssertNil(mock.dispatchReceivedAction)
        sut.dispatch("1")
        XCTAssertEqual("1", mock.dispatchReceivedAction)
        mock.dispatch("2")
        XCTAssertEqual("2", mock.dispatchReceivedAction)
        mock.dispatch("3")
        XCTAssertEqual("3", mock.dispatchReceivedAction)
        sut.dispatch("4")
        XCTAssertEqual("4", mock.dispatchReceivedAction)
        sut.dispatch("5")
        XCTAssertEqual("5", mock.dispatchReceivedAction)

        XCTAssertEqual(5, mock.dispatchCallsCount)
    }

    func testActionHandlerClosureErased() {
        var actions: [String] = []
        let sut = AnyActionHandler { action in
            actions.append(action)
        }

        sut.dispatch("1")
        sut.dispatch("2")
        sut.dispatch("3")
        sut.dispatch("4")
        sut.dispatch("5")

        XCTAssertEqual(["1", "2", "3", "4", "5"], actions)
    }

    func testActionHandlerContramap() {
        var actions: [String] = []
        let stringHandler = AnyActionHandler<String> { action in
            actions.append(action)
        }
        let intHandler: AnyActionHandler<Int> = stringHandler.contramap { "\($0)" }

        intHandler.dispatch(1)
        intHandler.dispatch(2)
        intHandler.dispatch(3)
        intHandler.dispatch(4)
        intHandler.dispatch(5)

        XCTAssertEqual(["1", "2", "3", "4", "5"], actions)
    }
}
