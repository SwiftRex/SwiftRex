import Foundation
@testable import SwiftRex
import XCTest

class DispatchQueueTests: XCTestCase {
    func testDispatchAsyncOnMainQueueAlready() {
        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        XCTAssert(DispatchQueue.isMainQueue)
        XCTAssert(Thread.isMainThread)
        DispatchQueue.main.async {
            XCTAssert(DispatchQueue.isMainQueue)
            XCTAssert(Thread.isMainThread)
            call1.fulfill()
        }
        XCTAssert(DispatchQueue.isMainQueue)
        XCTAssert(Thread.isMainThread)
        call2.fulfill()

        wait(for: [call2, call1], timeout: 0.1, enforceOrder: true)
    }

    func testDispatchAsyncOnMainQueueAlreadyDispatched() {
        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        DispatchQueue.main.async {
            XCTAssert(DispatchQueue.isMainQueue)
            XCTAssert(Thread.isMainThread)
            DispatchQueue.main.async {
                XCTAssert(DispatchQueue.isMainQueue)
                XCTAssert(Thread.isMainThread)
                call1.fulfill()
            }
            XCTAssert(DispatchQueue.isMainQueue)
            XCTAssert(Thread.isMainThread)
            call2.fulfill()
        }

        wait(for: [call2, call1], timeout: 0.1, enforceOrder: true)
    }

    func testDispatchAsapOnMainQueueAlready() {
        DispatchQueue.setMainQueueID()

        XCTAssert(DispatchQueue.isMainQueue)
        XCTAssert(Thread.isMainThread)
        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        DispatchQueue.asap {
            XCTAssert(DispatchQueue.isMainQueue)
            XCTAssert(Thread.isMainThread)
            call1.fulfill()
        }
        XCTAssert(DispatchQueue.isMainQueue)
        XCTAssert(Thread.isMainThread)
        call2.fulfill()

        wait(for: [call1, call2], timeout: 0.1, enforceOrder: true)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testDispatchAsapWithOptionsOnMainQueueAlready() {
        DispatchQueue.setMainQueueID()

        XCTAssert(DispatchQueue.isMainQueue)
        XCTAssert(Thread.isMainThread)
        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        DispatchQueue.asap(options: .init(qos: .background, flags: .detached, group: nil)) {
            XCTAssert(DispatchQueue.isMainQueue)
            XCTAssert(Thread.isMainThread)
            call1.fulfill()
        }
        XCTAssert(DispatchQueue.isMainQueue)
        XCTAssert(Thread.isMainThread)
        call2.fulfill()

        wait(for: [call1, call2], timeout: 0.1, enforceOrder: true)
    }

    func testDispatchAsapOnMainQueueAlreadyDispatched() {
        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        DispatchQueue.main.async {
            DispatchQueue.setMainQueueID()

            XCTAssert(DispatchQueue.isMainQueue)
            XCTAssert(Thread.isMainThread)

            DispatchQueue.asap {
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

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testDispatchAsapWithOptionsOnMainQueueAlreadyDispatched() {
        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        DispatchQueue.main.async {
            DispatchQueue.setMainQueueID()

            XCTAssert(DispatchQueue.isMainQueue)
            XCTAssert(Thread.isMainThread)

            DispatchQueue.asap(options: .init(qos: .background, flags: .detached, group: nil)) {
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

    func testDispatchAsapFromGlobalQueue() {
        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        DispatchQueue.main.async {
            DispatchQueue.setMainQueueID()

            DispatchQueue.global().async {
                XCTAssertFalse(DispatchQueue.isMainQueue)
                XCTAssertFalse(Thread.isMainThread)

                DispatchQueue.asap {
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

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testDispatchAsapWithOptionsFromGlobalQueue() {
        let call1 = expectation(description: "1")
        let call2 = expectation(description: "2")

        DispatchQueue.main.async {
            DispatchQueue.setMainQueueID()

            DispatchQueue.global().async {
                XCTAssertFalse(DispatchQueue.isMainQueue)
                XCTAssertFalse(Thread.isMainThread)

                DispatchQueue.asap(options: .init(qos: .background, flags: .detached, group: nil)) {
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
}
