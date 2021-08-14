import RxSwift
import RxSwiftRex
import SwiftRex
import XCTest

class EffectTests: XCTestCase { // swiftlint:disable:this type_body_length
    func testInitWithCancellation() {
        let sut = Effect<Void, Int>(token: "token") { _ in Observable.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }) }
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertEqual("token", sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testInitWithoutCancellation() {
        let sut = Effect<Void, Int> { _ in Observable.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }) }
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testInitWithoutCancellationNoDependencies() {
        let sut = Effect<Void, Int>(Observable.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) }))
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testInitWithoutCancellationIgnoringDependencies() {
        let sut: Effect<Int, Int> = Effect<Void, Int>(
            Observable.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) })
        ).ignoringDependencies()
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (42), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testInitWithCancellationNoDependenciesFromPublisherDispatchedAction() {
        let sut = Effect<Void, Int>(token: "token", effect: Observable.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]).map { DispatchedAction($0) })
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { error in XCTFail("Unexpected failure \(error)") },
                onCompleted: { completion += 1 }
            )
        XCTAssertEqual("token", sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testInitWithCancellationIgnoringDependencies() {
        let sut: Effect<String, Int> = Effect<Void, Int>(
            token: "token",
            effect: Observable.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
                .map { DispatchedAction($0) }
        )
        .ignoringDependencies()
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (""), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { error in XCTFail("Unexpected failure \(error)") },
                onCompleted: { completion += 1 }
            )
        XCTAssertEqual("token", sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testInitWithCancellationIgnoringDependenciesDoNothing() {
        let sut: Effect<String, Int> = Effect<Void, Int>.doNothing
            .ignoringDependencies()
        XCTAssertNil(sut.token)
        XCTAssertNil(sut.run((dependencies: (""), toCancel: { _ in FireAndForget { } })))
    }

    func testDoNothing() {
        let sut = Effect<Void, Int>.doNothing
        XCTAssertNil(sut.token)
        XCTAssertNil(sut.run((dependencies: (), toCancel: { _ in FireAndForget { } })))
    }

    func testJust() {
        let sut = Effect<Void, Int>.just(42)
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertEqual([42], received)
        XCTAssertEqual(1, completion)
    }

    func testJustWithDependencies() {
        let sut = Effect<Int, Int>.just { context in
            context.dependencies + 42
        }
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: 1, toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertEqual([43], received)
        XCTAssertEqual(1, completion)
    }

    func testSequenceArray() {
        let sut = Effect<Void, Int>.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testSequenceVariadics() {
        let sut = Effect<Void, Int>.sequence(1, 1, 2, 3, 5, 8, 13, 21, 34, 55)
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testPromise() {
        let sut = Effect<Int, String>.promise(token: "token") { context, callback in
            callback(String(context.dependencies + 1))
            return Disposables.create { }
        }
        var completion = 0
        var received = [String]()
        _ = sut
            .run((dependencies: 42, toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertEqual(["43"], received)
        XCTAssertEqual(1, completion)
    }

    func testAsEffectWithCancellation() {
        let sut = Observable.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]).asEffect(token: "token")
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertEqual("token", sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testAsEffectWithoutCancellation() {
        let sut = Observable.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]).asEffect(dispatcher: .here())
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55], received)
        XCTAssertEqual(1, completion)
    }

    func testFireAndForgetClosure() {
        let calledClosure = expectation(description: "should have called fire and forget closure")
        let sut = Effect<Void, Int>.fireAndForget {
            calledClosure.fulfill()
        }
        var completion = 0
        var received = [Int]()

        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )

        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([], received)
        XCTAssertEqual(1, completion)
    }

    func testFireAndForgetPublisher() {
        let calledClosure = expectation(description: "should have called fire and forget closure")
        let publisher = Observable.from(["test"]).do(onNext: { value in
            XCTAssertEqual(value, "test")
            calledClosure.fulfill()
        })
        let sut = Effect<Void, Int>.fireAndForget(publisher)
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([], received)
        XCTAssertEqual(1, completion)
    }

    func testFireAndForgetPublisherCatchErrorSuccess() {
        let calledClosure = expectation(description: "should have called fire and forget closure")
        let publisher = Observable.from(["test"]).do(onNext: { value in
            XCTAssertEqual(value, "test")
            calledClosure.fulfill()
        })
        let sut = Effect<Void, Int>.fireAndForget(
            publisher,
            catchErrors: { error in
                XCTFail(error.localizedDescription)
                return nil
            }
        )
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([], received)
        XCTAssertEqual(1, completion)
    }

    func testFireAndForgetPublisherCatchErrorFailure() {
        let calledClosure = expectation(description: "should have called fire and forget error closure")
        let someError = SomeError()
        let publisher = Observable<String>.error(someError).do(
            onNext: { _ in
                XCTFail("Success was not expected")
            },
            onError: { error in
                XCTAssertEqual(error as? SomeError, someError)
                calledClosure.fulfill()
            },
            onCompleted: {
                XCTFail("Success was not expected")
            }
        )
        let sut = Effect<Void, Int>.fireAndForget(
            publisher,
            catchErrors: { error in
                XCTAssertEqual(error as? SomeError, someError)
                return .init(42)
            }
        )
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        wait(for: [calledClosure], timeout: 0.1)
        XCTAssertEqual([42], received)
        XCTAssertEqual(1, completion)
    }

    func testMergeTwo() {
        let first = Observable.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) })
        let second = Observable.from([DispatchedAction(89)])
        let sut = Effect<Void, Int>(Observable.concat(first, second))
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual(1, completion)
    }

    func testMergeThree() {
        let first = Observable.from([1, 1, 2, 3, 5, 8, 13, 21].map { DispatchedAction($0) })
        let second = Observable.from([DispatchedAction(34)])
        let third = Observable.from([55, 89].map { DispatchedAction($0) })
        let sut = Effect<Void, Int>(Observable.concat(first, second, third))
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual(1, completion)
    }

    func testAppend() {
        let first = Observable.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55].map { DispatchedAction($0) })
        let second = Observable.from([DispatchedAction(89)])
        let sut = Effect(first.concat(second))
        var completion = 0
        var received = [Int]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertNil(sut.token)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89], received)
        XCTAssertEqual(1, completion)
    }

    func testFMap() {
        let numbers = Effect<Void, Int>.sequence([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
        let sut = numbers.map(String.init)
        var completion = 0
        var received = [String]()
        _ = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))?
            .subscribe(
                onNext: { received += [$0.action] },
                onError: { _ in XCTFail("should not fail") },
                onCompleted: { completion += 1 }
            )
        XCTAssertNil(sut.token)
        XCTAssertEqual(["1", "1", "2", "3", "5", "8", "13", "21", "34", "55"], received)
        XCTAssertEqual(1, completion)
    }

    func testFMapDoNothing() {
        let numbersDoNothing = Effect<Void, Int>.doNothing
        let sut = numbersDoNothing.map(String.init)
        let possibleEffect = sut
            .run((dependencies: (), toCancel: { _ in FireAndForget { } }))
        XCTAssertNil(sut.token)
        XCTAssertNil(possibleEffect)
    }

    func testFMapCancellation() {
        let shouldCallToCancel = expectation(description: "to cancel should have been called")
        let shouldHaveCancelledThePublisher = expectation(description: "publisher cancellation should have been called")
        let numbers = Effect<Void, Int>(token: "token") { context in
            Observable.concat(
                context.toCancel("123").asObservable(),

                Observable.from([1, 1, 2, 3, 5, 8, 13, 21, 34, 55])
                    .throttle(.milliseconds(20), scheduler: MainScheduler())
                    .map { DispatchedAction($0) }
            )
        }
        let sut = numbers.map(String.init)
        _ = sut
            .run((dependencies: (), toCancel: { token in
                XCTAssertEqual("123", token)
                shouldCallToCancel.fulfill()
                return FireAndForget { }
            }))?
            .do(onDispose: {
                shouldHaveCancelledThePublisher.fulfill()
            })
            .subscribe(
                onNext: { _ in },
                onError: { error in XCTFail("Unexpected failure \(error)") },
                onCompleted: { }
            )

        XCTAssertEqual("token", sut.token)
        wait(for: [shouldCallToCancel, shouldHaveCancelledThePublisher], timeout: 0.1)
    }
}
