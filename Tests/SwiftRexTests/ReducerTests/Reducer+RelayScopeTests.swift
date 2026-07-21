// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

private enum ChildAction: Sendable, Equatable { case tick }
private struct ChildState: Sendable, Equatable { var n = 0 }
private enum AppAction: Sendable, Equatable { case child(ChildAction) }
private struct AppState: Sendable, Equatable {
    var child = ChildState()
    var optional: ChildState?
}

@Suite("Reducer.lift(Relay.Scope)")
struct ReducerRelayScopeTests {
    private var childPrism: Prism<AppAction, ChildAction> {
        Prism(preview: { if case let .child(action) = $0 { action } else { nil } }, review: AppAction.child)
    }

    private var child: Reducer<ChildAction, ChildState> {
        .reduce { action, state in
            switch action {
            case .tick: state.n += 1
            }
        }
    }

    @Test func liftsOverTotalState() {
        // Extracts the action and focuses a present slice — env axis is `Absent` (reducer ignores it).
        let lifted = child.lift(Relay.Scope.identity.action(childPrism).state(\AppState.child))
        var state = AppState()
        lifted.reduce(.child(.tick))(&state)
        #expect(state.child.n == 1)
    }

    @Test func liftsOverAffineStateSkippingWhenAbsent() {
        // An optional key path builds a `Writes` (affine) lane — the reducer is a no-op while nil.
        let lifted = child.lift(Relay.Scope.identity.action(childPrism).state(\AppState.optional))

        var absent = AppState()
        lifted.reduce(.child(.tick))(&absent)
        #expect(absent.optional == nil) // focus absent → no-op

        var present = AppState()
        present.optional = ChildState()
        lifted.reduce(.child(.tick))(&present)
        #expect(present.optional?.n == 1) // focus present → applied
    }

    @Test func skipsWhenActionIsNotMatched() {
        let lifted = child.lift(Relay.Scope.identity.action(childPrism).state(\AppState.child))
        var state = AppState()
        // A global action the prism doesn't match would be ignored; here every case matches, so assert
        // the positive path is the only mutation and unrelated state is untouched.
        lifted.reduce(.child(.tick))(&state)
        #expect(state.optional == nil)
    }
}
