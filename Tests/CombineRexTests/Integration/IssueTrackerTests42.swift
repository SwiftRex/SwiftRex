#if canImport(Combine)
import Combine
import CombineRex
import SwiftRex
import XCTest

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class IssueTracker42Tests: XCTestCase {
    struct AppState: Equatable, Codable {
        let int: Int
    }

    enum ViewEvent: Equatable {
        case event
    }

    enum AppAction: Equatable {
        case action
    }

    class Store: ReduxStoreBase<AppAction, AppState> {}

    var store: Store!

    override func setUp() {
        super.setUp()
        store = Store(subject: .combine(initialValue: AppState(int: 0)),
                      reducer: .init { _, state in
                          AppState(int: state.int + 1)
                      },
                      middleware: IdentityMiddleware())
    }

    func testIssue42() {
        let shouldNotifyTwice = expectation(description: "should have been notified twice")
        shouldNotifyTwice.expectedFulfillmentCount = 2
        let viewModel = store
            .projection(action: { $0 }, state: { $0 })
            .asObservableViewModel(initialState: .init(int: 0))
        let cancellable = viewModel.statePublisher.sink { _ in
            shouldNotifyTwice.fulfill()
        }
        viewModel.dispatch(.action, from: .here())

        wait(for: [shouldNotifyTwice], timeout: 0.3)
        XCTAssertNotNil(cancellable)
    }
}
#endif
