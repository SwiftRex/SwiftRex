// Generated using Sourcery 1.6.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all
import Foundation
@testable import SwiftRex
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif













class ActionHandlerMock<ActionType>: ActionHandler {

    //MARK: - dispatch

    var dispatchCallsCount = 0
    var dispatchCalled: Bool {
        return dispatchCallsCount > 0
    }
    var dispatchReceivedDispatchedAction: DispatchedAction<ActionType>?
    var dispatchClosure: ((DispatchedAction<ActionType>) -> Void)?

    func dispatch(_ dispatchedAction: DispatchedAction<ActionType>) {
        dispatchCallsCount += 1
        dispatchReceivedDispatchedAction = dispatchedAction
        dispatchClosure?(dispatchedAction)
    }

}
class MiddlewareProtocolMock<InputActionType, OutputActionType, StateType>: MiddlewareProtocol {

    //MARK: - handle

    var handleActionFromStateCallsCount = 0
    var handleActionFromStateCalled: Bool {
        return handleActionFromStateCallsCount > 0
    }
    var handleActionFromStateReceivedArguments: (action: InputActionType, dispatcher: ActionSource, state: GetState<StateType>)?
    var handleActionFromStateReturnValue: IO<OutputActionType>!
    var handleActionFromStateClosure: ((InputActionType, ActionSource, @escaping GetState<StateType>) -> IO<OutputActionType>)?

    func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType> {
        handleActionFromStateCallsCount += 1
        handleActionFromStateReceivedArguments = (action: action, dispatcher: dispatcher, state: state)
        return handleActionFromStateClosure.map({ $0(action, dispatcher, state) }) ?? handleActionFromStateReturnValue
    }

    //MARK: - receiveContext

    var receiveContextGetStateOutputCallsCount = 0
    var receiveContextGetStateOutputCalled: Bool {
        return receiveContextGetStateOutputCallsCount > 0
    }
    var receiveContextGetStateOutputReceivedArguments: (getState: GetState<StateType>, output: AnyActionHandler<OutputActionType>)?
    var receiveContextGetStateOutputClosure: ((@escaping GetState<StateType>, AnyActionHandler<OutputActionType>) -> Void)?

    func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>) {
        receiveContextGetStateOutputCallsCount += 1
        receiveContextGetStateOutputReceivedArguments = (getState: getState, output: output)
        receiveContextGetStateOutputClosure?(getState, output)
    }

}
class ReduxStoreProtocolMock<ActionType, StateType>: ReduxStoreProtocol {
    var pipeline: ReduxPipelineWrapper<MiddlewareType> {
        get { return underlyingPipeline }
        set(value) { underlyingPipeline = value }
    }
    var underlyingPipeline: ReduxPipelineWrapper<MiddlewareType>!
    var statePublisher: UnfailablePublisherType<StateType> {
        get { return underlyingStatePublisher }
        set(value) { underlyingStatePublisher = value }
    }
    var underlyingStatePublisher: UnfailablePublisherType<StateType>!

}
class StateProviderMock<StateType>: StateProvider {
    var statePublisher: UnfailablePublisherType<StateType> {
        get { return underlyingStatePublisher }
        set(value) { underlyingStatePublisher = value }
    }
    var underlyingStatePublisher: UnfailablePublisherType<StateType>!

}
class StoreTypeMock<ActionType, StateType>: StoreType {
    var statePublisher: UnfailablePublisherType<StateType> {
        get { return underlyingStatePublisher }
        set(value) { underlyingStatePublisher = value }
    }
    var underlyingStatePublisher: UnfailablePublisherType<StateType>!

    //MARK: - dispatch

    var dispatchCallsCount = 0
    var dispatchCalled: Bool {
        return dispatchCallsCount > 0
    }
    var dispatchReceivedDispatchedAction: DispatchedAction<ActionType>?
    var dispatchClosure: ((DispatchedAction<ActionType>) -> Void)?

    func dispatch(_ dispatchedAction: DispatchedAction<ActionType>) {
        dispatchCallsCount += 1
        dispatchReceivedDispatchedAction = dispatchedAction
        dispatchClosure?(dispatchedAction)
    }

}
