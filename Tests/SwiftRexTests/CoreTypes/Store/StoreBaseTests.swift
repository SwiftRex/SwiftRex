import Foundation
@testable import SwiftRex
import XCTest

class StoreBaseTests: XCTestCase {
//    func testStoreFullWorkflow() { // swiftlint:disable:this function_body_length
//        let events: [EventProtocol] = [Event1(), Event3(), Event1(), Event2()]
//        let initialState = TestState()
//        let translateMiddleware = MiddlewareMock<TestState>()
//        translateMiddleware.handleEventGetStateNextClosure = { [weak translateMiddleware] event, getState, next in
//            next(event, getState)
//            XCTAssertEqual(initialState.value, getState().value)
//            var action: ActionProtocol?
//            switch event {
//            case is Event1: action = Action1()
//            case is Event2: action = Action2()
//            case is Event3: action = Action3()
//            default: XCTFail("Unexpected event")
//            }
//            action.map { translateMiddleware?.context().actionHandler.trigger($0) }
//        }
//        translateMiddleware.handleActionGetStateNextClosure = { action, getState, next in
//            next(action, getState)
//            XCTAssertEqual(initialState.value, getState().value)
//        }
//        let subjectMock = CurrentValueSubject(currentValue: initialState)
//        let reducer: Reducer<TestState> = Reducer { state, event in
//            TestState(
//                value: state.value,
//                name: state.name + (
//                    (event as? Action1)?.name ??
//                        (event as? Action2)?.name ??
//                        (event as? Action3)?.name ??
//                    "not expected"
//                )
//            )
//        }
//        let store = TestStore(subject: subjectMock.subject,
//                              reducer: reducer,
//                              middleware: translateMiddleware)
//
//        var count = 0
//        let shouldBeCalled4Times = expectation(description: "it should be called 4 times")
//        _ = store.statePublisher.subscribe(SubscriberType(onValue: { value in
//            switch count {
//            case 0: XCTAssertEqual("a1", value.name)
//            case 1: XCTAssertEqual("a1a3", value.name)
//            case 2: XCTAssertEqual("a1a3a1", value.name)
//            case 3:
//                XCTAssertEqual("a1a3a1a2", value.name)
//                shouldBeCalled4Times.fulfill()
//            default: XCTFail("Called more times than expected")
//            }
//            count += 1
//        }, onCompleted: { error in XCTFail("Unexpected completion. Error? \(String(describing: error))") }))
//
//        // Then
//        events.forEach(store.eventHandler.dispatch)
//
//        // Expect
//        wait(for: [shouldBeCalled4Times], timeout: 0.5)
//    }
}
