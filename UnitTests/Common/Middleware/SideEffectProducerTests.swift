@testable import SwiftRex
import XCTest

class SideEffectProducerTests: XCTestCase {
    func testAnySideEffectProducerEvent() {
        // Given
        let sepMock = SideEffectProducerMock<TestState>()
        let sut = AnySideEffectProducer(sepMock)
        let state = TestState()
        let getState = { state }
        let action1 = Action1()
        let action2 = Action2()
        let action3 = Action3()
        sepMock.executeGetStateReturnValue = PublisherType(subscribe: { subscriber in
            subscriber.onValue(action1)
            subscriber.onValue(action2)
            subscriber.onValue(action3)
            return FooSubscription()
        })

        // Then
        var actions: [ActionProtocol] = []
        _ = sut.execute(getState: getState).subscribe(SubscriberType(
            onValue: { actions.append($0) }, onError: { error in XCTFail("Unexpected error: \(error)") }
        ))

        // Expect
        XCTAssertEqual(1, sepMock.executeGetStateCallsCount)
        XCTAssertEqual(state, sepMock.executeGetStateReceivedGetState!())
        let expectedResult: [ActionProtocol] = [action1, action2, action3]
        XCTAssertEqual(3, actions.count)
        XCTAssertEqual(expectedResult[0] as! Action1, actions[0] as! Action1)
        XCTAssertEqual(expectedResult[1] as! Action2, actions[1] as! Action2)
        XCTAssertEqual(expectedResult[2] as! Action3, actions[2] as! Action3)
    }
}
