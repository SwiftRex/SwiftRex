import Combine
import Foundation
@testable import SwiftRex
import XCTest

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class ASAPSchedulerTests: XCTestCase {
    func testASAPSchedulerOnMainQueueAlready() {
        let scheduler = ASAPScheduler.default

        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        scheduler.schedule {
            XCTAssert(DispatchQueue.isMainQueue)
            XCTAssert(Thread.isMainThread)
            XCTAssertEqual(scheduler.minimumTolerance, DispatchQueue.main.minimumTolerance)
            call1.fulfill()
        }
        XCTAssert(DispatchQueue.isMainQueue)
        XCTAssert(Thread.isMainThread)
        call2.fulfill()

        wait(for: [call1, call2], timeout: 0.1, enforceOrder: true)
    }

    func testASAPSchedulerWithOptionsOnMainQueueAlready() {
        let scheduler = ASAPScheduler.default

        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        scheduler.schedule(options: .init(qos: .background, flags: .detached, group: nil)) {
            XCTAssert(DispatchQueue.isMainQueue)
            XCTAssert(Thread.isMainThread)
            call1.fulfill()
        }
        XCTAssert(DispatchQueue.isMainQueue)
        XCTAssert(Thread.isMainThread)
        call2.fulfill()

        wait(for: [call1, call2], timeout: 0.1, enforceOrder: true)
    }

    func testASAPSchedulerOnMainQueueAlreadyDispatched() {
        let scheduler = ASAPScheduler.default

        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        DispatchQueue.main.async {
            XCTAssert(DispatchQueue.isMainQueue)
            XCTAssert(Thread.isMainThread)

            scheduler.schedule {
                XCTAssert(DispatchQueue.isMainQueue)
                XCTAssert(Thread.isMainThread)
                call1.fulfill()
            }
            XCTAssert(DispatchQueue.isMainQueue)
            XCTAssert(Thread.isMainThread)
            call2.fulfill()
        }

        wait(for: [call1, call2], timeout: 0.1, enforceOrder: true)
    }

    func testASAPSchedulerWithOptionsOnMainQueueAlreadyDispatched() {
        let scheduler = ASAPScheduler.default

        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        DispatchQueue.main.async {
            XCTAssert(DispatchQueue.isMainQueue)
            XCTAssert(Thread.isMainThread)

            scheduler.schedule(options: .init(qos: .background, flags: .detached, group: nil)) {
                XCTAssert(DispatchQueue.isMainQueue)
                XCTAssert(Thread.isMainThread)
                call1.fulfill()
            }
            XCTAssert(DispatchQueue.isMainQueue)
            XCTAssert(Thread.isMainThread)
            call2.fulfill()
        }

        wait(for: [call1, call2], timeout: 0.1, enforceOrder: true)
    }

    func testASAPSchedulerFromGlobalQueue() {
        let scheduler = ASAPScheduler.default

        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        DispatchQueue.main.async {
            DispatchQueue.global().async {
                XCTAssertFalse(DispatchQueue.isMainQueue)
                XCTAssertFalse(Thread.isMainThread)

                scheduler.schedule {
                    XCTAssert(DispatchQueue.isMainQueue)
                    XCTAssert(Thread.isMainThread)
                    call1.fulfill()
                }
                XCTAssertFalse(DispatchQueue.isMainQueue)
                XCTAssertFalse(Thread.isMainThread)
                call2.fulfill()
            }
        }

        wait(for: [call2, call1], timeout: 0.1, enforceOrder: true)
    }

    func testASAPSchedulerWithOptionsFromGlobalQueue() {
        let scheduler = ASAPScheduler.default

        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        DispatchQueue.main.async {
            DispatchQueue.global().async {
                XCTAssertFalse(DispatchQueue.isMainQueue)
                XCTAssertFalse(Thread.isMainThread)

                scheduler.schedule(options: .init(qos: .background, flags: .detached, group: nil)) {
                    XCTAssert(DispatchQueue.isMainQueue)
                    XCTAssert(Thread.isMainThread)
                    call1.fulfill()
                }
                XCTAssertFalse(DispatchQueue.isMainQueue)
                XCTAssertFalse(Thread.isMainThread)
                call2.fulfill()
            }
        }

        wait(for: [call2, call1], timeout: 0.1, enforceOrder: true)
    }

    func testASAPSchedulerAfterUsesMainQueue() {
        let scheduler = ASAPScheduler.default

        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        DispatchQueue.main.async {
            DispatchQueue.global().async {
                XCTAssertFalse(DispatchQueue.isMainQueue)
                XCTAssertFalse(Thread.isMainThread)

                scheduler.schedule(after: scheduler.now.advanced(by: .milliseconds(50)), tolerance: .zero, options: .init()) {
                    XCTAssert(DispatchQueue.isMainQueue)
                    XCTAssert(Thread.isMainThread)
                    call1.fulfill()
                }
                XCTAssertFalse(DispatchQueue.isMainQueue)
                XCTAssertFalse(Thread.isMainThread)
                call2.fulfill()
            }
        }

        wait(for: [call2, call1], timeout: 0.1, enforceOrder: true)
    }

    func testASAPSchedulerRecurringUsesMainQueue() {
        let scheduler = ASAPScheduler.default

        let call1 = expectation(description: "1")
        call1.expectedFulfillmentCount = 2
        call1.assertForOverFulfill = true
        let call2 = expectation(description: "2")
        var timerHandle: Cancellable?

        DispatchQueue.main.async {
            DispatchQueue.global().async {
                XCTAssertFalse(DispatchQueue.isMainQueue)
                XCTAssertFalse(Thread.isMainThread)

                timerHandle = scheduler.schedule(after: scheduler.now.advanced(by: .milliseconds(5)),
                                                 interval: .milliseconds(60),
                                                 tolerance: .zero,
                                                 options: .init()) {
                    XCTAssert(DispatchQueue.isMainQueue)
                    XCTAssert(Thread.isMainThread)
                    call1.fulfill()
                }
                XCTAssertFalse(DispatchQueue.isMainQueue)
                XCTAssertFalse(Thread.isMainThread)
                call2.fulfill()
            }
        }

        wait(for: [call2, call1], timeout: 0.1, enforceOrder: true)
        timerHandle?.cancel()
    }
}
