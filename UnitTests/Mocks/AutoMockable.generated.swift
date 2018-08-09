// Generated using Sourcery 0.13.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import Foundation
import RxSwift
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
    var executeGetStateReturnValue: Observable<ActionProtocol>!
    var executeGetStateClosure: ((@escaping GetState<StateType>) -> Observable<ActionProtocol>)?

    func execute(getState: @escaping GetState<StateType>) -> Observable<ActionProtocol> {
        executeGetStateCallsCount += 1
        executeGetStateReceivedGetState = getState
        return executeGetStateClosure.map({ $0(getState) }) ?? executeGetStateReturnValue
    }

}
