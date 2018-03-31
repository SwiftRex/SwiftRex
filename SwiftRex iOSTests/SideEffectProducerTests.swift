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
        let event = Event1()
        let state = TestState()
        let getState = { state }
        let action1 = Action1()
        let action2 = Action2()
        let action3 = Action3()
        sepMock.handleEventGetStateReturnValue = Observable.of(action1, action2, action3)

        // Then
        let result = try! sut.handle(event: event, getState: getState)
            .toBlocking()
            .toArray()

        // Expect
        XCTAssertEqual(1, sepMock.handleEventGetStateCallsCount)
        XCTAssertEqual(event, sepMock.handleEventGetStateReceivedArguments!.event as! Event1)
        XCTAssertEqual(state, sepMock.handleEventGetStateReceivedArguments!.getState())
        let expectedResult: [Action] = [action1, action2, action3]
        XCTAssertEqual(3, result.count)
        XCTAssertEqual(expectedResult[0] as! Action1, result[0] as! Action1)
        XCTAssertEqual(expectedResult[1] as! Action2, result[1] as! Action2)
        XCTAssertEqual(expectedResult[2] as! Action3, result[2] as! Action3)
    }

    func testTimelySideEffectEventOneAction() {
        // Given
        let sut = AnySideEffectProducer(TimelySideEffect(name: "tse"))
        let state = TestState()
        let getState = { state }
        let event = Event1()

        // Then
        let result = try! sut.handle(event: event, getState: getState)
            .toBlocking()
            .toArray()

        // Expect
        XCTAssertEqual(1, result.count)
        XCTAssertEqual("tse-a1", (result[0] as! Action1).name)
    }

    func testTimelySideEffectEventTwoActions() {
        // Given
        let sut = AnySideEffectProducer(TimelySideEffect(name: "tse"))
        let state = TestState()
        let getState = { state }
        let event = Event2()

        // Then
        let result = try! sut.handle(event: event, getState: getState)
            .toBlocking()
            .toArray()

        // Expect
        XCTAssertEqual(2, result.count)
        XCTAssertEqual("tse-a2", (result[0] as! Action2).name)
        XCTAssertEqual("tse-a3", (result[1] as! Action3).name)
    }

    func testTimelySideEffectEventThreeActions() {
        // Given
        let sut = AnySideEffectProducer(TimelySideEffect(name: "tse"))
        let state = TestState()
        let getState = { state }
        let event = Event3()

        // Then
        let result = try! sut.handle(event: event, getState: getState)
            .toBlocking()
            .toArray()

        // Expect
        XCTAssertEqual(3, result.count)
        XCTAssertEqual("tse-a3", (result[0] as! Action3).name)
        XCTAssertEqual("tse-a1", (result[1] as! Action1).name)
        XCTAssertEqual("tse-a2", (result[2] as! Action2).name)
    }
}
