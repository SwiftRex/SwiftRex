import Combine
import CombineRex
import Foundation
import SwiftRex
import XCTest

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.store.dispatch(.event(.requestIncrease), from: .here())
            self.store.dispatch(.event(.requestIncrease), from: .here())
            self.store.dispatch(.event(.requestIncrease), from: .here())
            self.store.dispatch(.event(.requestDecrease), from: .here())
            self.store.dispatch(.event(.requestIncrease), from: .here())
            self.store.dispatch(.event(.requestDecrease), from: .here())
            self.store.dispatch(.event(.requestDecrease), from: .here())
        }

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

    static let reducer = Reducer<AppAction.CounterAction, Int>.reduce { action, state in
        print("reducing \(action) from state \(state)")
        switch action {
        case .increase: state += 1
        case .decrease: state -= 1
        }
    }

    class CounterMiddleware: Middleware {
        typealias InputActionType = AppAction.CounterEvent
        typealias OutputActionType = AppAction.CounterAction
        typealias StateType = Int

        var getState: (() -> Int)!
        var output: AnyActionHandler<AppAction.CounterAction>!

        func receiveContext(getState: @escaping GetState<Int>, output: AnyActionHandler<AppAction.CounterAction>) {
            self.getState = getState
            self.output = output
        }

        func handle(action: AppAction.CounterEvent, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
            afterReducer = .do { [unowned self] in
                switch action {
                case .requestIncrease: self.output.dispatch(.increase, from: .here())
                case .requestDecrease: self.output.dispatch(.decrease, from: .here())
                }
            }
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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
                    inputAction: { $0.event },
                    outputAction: { AppAction.action($0) },
                    state: { $0.currentNumber }
                ),
            emitsValue: .whenDifferent
        )
    }
}

enum ViewEvent: Equatable {
    case tapIncrease, tapDecrease
}
