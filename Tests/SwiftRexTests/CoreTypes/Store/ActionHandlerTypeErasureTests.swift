import Foundation
@testable import SwiftRex
import XCTest

class ActionHandlerTypeErasureTests: XCTestCase {
    func testActionHandlerMockErased() {
        let mock = ActionHandlerMock<String>()
        let sut = mock.eraseToAnyActionHandler()
        XCTAssertNil(mock.dispatchFromReceivedArguments?.action)
        sut.dispatch("1", from: .here())
        XCTAssertEqual("1", mock.dispatchFromReceivedArguments?.action)
        mock.dispatch("2", from: .here())
        XCTAssertEqual("2", mock.dispatchFromReceivedArguments?.action)
        mock.dispatch("3", from: .here())
        XCTAssertEqual("3", mock.dispatchFromReceivedArguments?.action)
        sut.dispatch("4", from: .here())
        XCTAssertEqual("4", mock.dispatchFromReceivedArguments?.action)
        sut.dispatch("5", from: .here())
        XCTAssertEqual("5", mock.dispatchFromReceivedArguments?.action)

        XCTAssertEqual(5, mock.dispatchFromCallsCount)
    }

    func testActionHandlerClosureErased() {
        var actions: [String] = []
        let sut = AnyActionHandler { action, _ in
            actions.append(action)
        }

        sut.dispatch("1", from: .here())
        sut.dispatch("2", from: .here())
        sut.dispatch("3", from: .here())
        sut.dispatch("4", from: .here())
        sut.dispatch("5", from: .here())

        XCTAssertEqual(["1", "2", "3", "4", "5"], actions)
    }

    func testActionHandlerContramap() {
        var actions: [String] = []
        let stringHandler = AnyActionHandler<String> { action, _ in
            actions.append(action)
        }
        let intHandler: AnyActionHandler<Int> = stringHandler.contramap { "\($0)" }

        intHandler.dispatch(1, from: .here())
        intHandler.dispatch(2, from: .here())
        intHandler.dispatch(3, from: .here())
        intHandler.dispatch(4, from: .here())
        intHandler.dispatch(5, from: .here())

        XCTAssertEqual(["1", "2", "3", "4", "5"], actions)
    }
}
