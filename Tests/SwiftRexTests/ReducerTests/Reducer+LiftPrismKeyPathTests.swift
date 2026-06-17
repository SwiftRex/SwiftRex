import CoreFP
@testable import SwiftRex
import Testing

// Hand-rolled `Prismatic` action (the shape `@Prisms` generates) so the test exercises the
// generated `PrismKeyPath` lift twins without depending on the macro module.
private enum AppAction: Equatable, Sendable {
    case counter(Int)
    case other(String)
}

extension AppAction: Prismatic {
    struct Prisms: Sendable {
        let counter = Prism<AppAction, Int>(
            preview: { if case .counter(let value) = $0 { value } else { nil } },
            review: AppAction.counter
        )
        let other = Prism<AppAction, String>(
            preview: { if case .other(let value) = $0 { value } else { nil } },
            review: AppAction.other
        )
    }
    static let prism = Prisms()
}

private struct AppState: Equatable, Sendable {
    var count: Int = 0
}

@Suite("Reducer — PrismKeyPath action lifting (generated twins)")
struct ReducerPrismKeyPathLiftTests {
    private let bump = Reducer<Int, Int>.reduce { delta, n in n += delta }

    @Test func liftActionOnlyViaPrismKeyPath() {
        let lifted: Reducer<AppAction, Int> = bump.lift(action: \.counter)
        var state = 0
        lifted.reduce(.counter(5))(&state)
        #expect(state == 5)
        lifted.reduce(.other("ignored"))(&state) // not matched by \.counter → no-op
        #expect(state == 5)
    }

    @Test func liftActionAndStateViaPrismKeyPath() {
        let lifted: Reducer<AppAction, AppState> = bump.lift(action: \.counter, state: \AppState.count)
        var state = AppState()
        lifted.reduce(.counter(3))(&state)
        #expect(state.count == 3)
        lifted.reduce(.other("ignored"))(&state)
        #expect(state.count == 3)
    }
}
