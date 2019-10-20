//
//  IntegrationCounterTests.swift
//  UnitTests Combine
//
//  Created by Luiz Rodrigo Martins Barbosa on 20.10.19.
//

import Combine
import CombineRex
import Foundation
import SwiftRex
import XCTest

class IntegrationCounterTests: XCTestCase {
    var store: TestBasicStore!
    var subscription: AnyCancellable?

    override func setUp() {
        super.setUp()
        store = TestBasicStore()
    }

    func testDispatchToStore() {
        var stateChanges: [String] = []
        let shouldCallEightTimes = expectation(description: "sink closure should have been called 8 times")
        shouldCallEightTimes.expectedFulfillmentCount = 8
        subscription = store
            .statePublisher
            .map { String(data: try! JSONEncoder().encode($0), encoding: .utf8)! }
            .sink {
                stateChanges.append("\($0)")
                print("\($0)")
                shouldCallEightTimes.fulfill()
            }
        store.dispatch(.event(.requestIncrease))
        store.dispatch(.event(.requestIncrease))
        store.dispatch(.event(.requestIncrease))
        store.dispatch(.event(.requestDecrease))
        store.dispatch(.event(.requestIncrease))
        store.dispatch(.event(.requestDecrease))
        store.dispatch(.event(.requestDecrease))

        wait(for: [shouldCallEightTimes], timeout: 1)
        XCTAssertEqual(stateChanges, [
            "{\"currentNumber\":0}",
            "{\"currentNumber\":1}",
            "{\"currentNumber\":2}",
            "{\"currentNumber\":3}",
            "{\"currentNumber\":2}",
            "{\"currentNumber\":3}",
            "{\"currentNumber\":2}",
            "{\"currentNumber\":1}"
        ])
    }
}

enum AppAction: Equatable {
    case event(CounterEvent)
    case action(CounterAction)

    enum CounterEvent: Equatable {
        case requestIncrease, requestDecrease
    }

    enum CounterAction: Equatable {
        case increase, decrease
    }

    var event: CounterEvent? {
        get {
            guard case let .event(value) = self else { return nil }
            return value
        }
        set {
            guard case .event = self, let newValue = newValue else { return }
            self = .event(newValue)
        }
    }

    var action: CounterAction? {
        get {
            guard case let .action(value) = self else { return nil }
            return value
        }
        set {
            guard case .action = self, let newValue = newValue else { return }
            self = .action(newValue)
        }
    }
}

struct AppState: Codable, Equatable {
    var currentNumber = 0
}

enum CounterService {
    static let middleware = CounterMiddleware()

    static let reducer = Reducer<AppAction.CounterAction, Int> { action, state in
        print("reducing \(action) from state \(state)")
        switch action {
        case .increase: return state + 1
        case .decrease: return state - 1
        }
    }

    class CounterMiddleware: Middleware {
        typealias InputActionType = AppAction.CounterEvent
        typealias OutputActionType = AppAction.CounterAction
        typealias StateType = Int

        var context: () -> MiddlewareContext<AppAction.CounterAction, Int> = { fatalError("Not set yet") }

        func handle(action: AppAction.CounterEvent, next: @escaping Next) {
            next()
            switch action {
            case .requestIncrease: context().dispatch(.increase)
            case .requestDecrease: context().dispatch(.decrease)
            }
        }
    }
}

final class TestBasicStore: ReduxStoreBase<AppAction, AppState> {
    init() {
        super.init(
            subject: .combine(initialValue: AppState()),
            reducer:
                CounterService.reducer.lift(
                    action: \AppAction.action,
                    state: \AppState.currentNumber
                ),
            middleware:
                CounterService.middleware.lift(
                    actionZoomIn: { $0.event },
                    actionZoomOut: { AppAction.action($0) },
                    stateZoomIn: { $0.currentNumber }
                ),
            emitsChange: .whenChange
        )
    }
}

enum ViewEvent: Equatable {
    case tapIncrease, tapDecrease
}
