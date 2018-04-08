import RxBlocking
import RxSwift
import RxTest
@testable import SwiftRex
import XCTest

class SideEffectProducerTests: XCTestCase {
    func testAnySideEffectProducerEvent() {
        // Given
        let sepMock = SideEffectProducerMock()
        let sut = AnySideEffectProducer(sepMock)
        let state = TestState()
        let getState = { state }
        let action1 = Action1()
        let action2 = Action2()
        let action3 = Action3()
        sepMock.executeGetStateReturnValue = Observable.of(action1, action2, action3)

        // Then
        let result = try! sut.execute(getState: getState)
            .toBlocking()
            .toArray()

        // Expect
        XCTAssertEqual(1, sepMock.executeGetStateCallsCount)
        XCTAssertEqual(state, sepMock.executeGetStateReceivedGetState!())
        let expectedResult: [ActionProtocol] = [action1, action2, action3]
        XCTAssertEqual(3, result.count)
        XCTAssertEqual(expectedResult[0] as! Action1, result[0] as! Action1)
        XCTAssertEqual(expectedResult[1] as! Action2, result[1] as! Action2)
        XCTAssertEqual(expectedResult[2] as! Action3, result[2] as! Action3)
    }

    func testTimelySideEffectEventOneAction() {
        // Given
        let event = Event1()
        let sut = AnySideEffectProducer(TimelySideEffect(event: event, name: "tse"))
        let state = TestState()
        let getState = { state }

        // Then
        let result = try! sut.execute(getState: getState)
            .toBlocking()
            .toArray()

        // Expect
        XCTAssertEqual(1, result.count)
        XCTAssertEqual("tse-a1", (result[0] as! Action1).name)
    }

    func testTimelySideEffectEventTwoActions() {
        // Given
        let event = Event2()
        let sut = AnySideEffectProducer(TimelySideEffect(event: event, name: "tse"))
        let state = TestState()
        let getState = { state }

        // Then
        let result = try! sut.execute(getState: getState)
            .toBlocking()
            .toArray()

        // Expect
        XCTAssertEqual(2, result.count)
        XCTAssertEqual("tse-a2", (result[0] as! Action2).name)
        XCTAssertEqual("tse-a3", (result[1] as! Action3).name)
    }

    func testTimelySideEffectEventThreeActions() {
        // Given
        let event = Event3()
        let sut = AnySideEffectProducer(TimelySideEffect(event: event, name: "tse"))
        let state = TestState()
        let getState = { state }

        // Then
        let result = try! sut.execute(getState: getState)
            .toBlocking()
            .toArray()

        // Expect
        XCTAssertEqual(3, result.count)
        XCTAssertEqual("tse-a3", (result[0] as! Action3).name)
        XCTAssertEqual("tse-a1", (result[1] as! Action1).name)
        XCTAssertEqual("tse-a2", (result[2] as! Action2).name)
    }
}
