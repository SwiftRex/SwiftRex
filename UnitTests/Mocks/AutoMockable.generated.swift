// Generated using Sourcery 0.16.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import Foundation
@testable import SwiftRex
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

class SideEffectProducerMock: SideEffectProducer {
    // MARK: - execute

    var executeGetStateCallsCount = 0
    var executeGetStateCalled: Bool {
        return executeGetStateCallsCount > 0
    }
    var executeGetStateReceivedGetState: (GetState<StateType>)?
    var executeGetStateReturnValue: PublisherType<ActionProtocol, Error>!
    var executeGetStateClosure: ((@escaping GetState<StateType>) -> PublisherType<ActionProtocol, Error>)?

    func execute(getState: @escaping GetState<StateType>) -> PublisherType<ActionProtocol, Error> {
        executeGetStateCallsCount += 1
        executeGetStateReceivedGetState = getState
        return executeGetStateClosure.map({ $0(getState) }) ?? executeGetStateReturnValue
    }
}
