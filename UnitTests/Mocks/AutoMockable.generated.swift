// Generated using Sourcery 0.16.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import Foundation
@testable import SwiftRex
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

class ActionHandlerMock: ActionHandler {

    // MARK: - trigger

    var triggerCallsCount = 0
    var triggerCalled: Bool {
        return triggerCallsCount > 0
    }
    var triggerReceivedAction: ActionProtocol?
    var triggerClosure: ((ActionProtocol) -> Void)?

    func trigger(_ action: ActionProtocol) {
        triggerCallsCount += 1
        triggerReceivedAction = action
        triggerClosure?(action)
    }

}
class SideEffectProducerMock: SideEffectProducer {

    // MARK: - execute

    var executeGetStateCallsCount = 0
    var executeGetStateCalled: Bool {
        return executeGetStateCallsCount > 0
    }
    var executeGetStateReceivedGetState: (GetState<StateType>)?
    var executeGetStateReturnValue: FailableObservableSignalProducer<ActionProtocol>!
    var executeGetStateClosure: ((@escaping GetState<StateType>) -> FailableObservableSignalProducer<ActionProtocol>)?

    func execute(getState: @escaping GetState<StateType>) -> FailableObservableSignalProducer<ActionProtocol> {
        executeGetStateCallsCount += 1
        executeGetStateReceivedGetState = getState
        return executeGetStateClosure.map({ $0(getState) }) ?? executeGetStateReturnValue
    }

}
