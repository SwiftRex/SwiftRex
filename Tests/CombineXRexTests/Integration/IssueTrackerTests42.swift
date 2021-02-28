import CombineX
import CombineXRex
import CXFoundation
import SwiftRex
import XCTest

class IssueTracker42Tests: XCTestCase {
    struct AppState: Equatable, Codable {
        var int: Int
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
        store = Store(subject: .combineX(initialValue: AppState(int: 0)),
                      reducer: .reduce { _, state in
                          state.int += 1
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
