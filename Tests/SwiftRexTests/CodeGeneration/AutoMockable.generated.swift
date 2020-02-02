// Generated using Sourcery 0.17.0 — https://github.com/krzysztofzablocki/Sourcery
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
    var dispatchReceivedAction: ActionType?
    var dispatchClosure: ((ActionType) -> Void)?

    func dispatch(_ action: ActionType) {
        dispatchCallsCount += 1
        dispatchReceivedAction = action
        dispatchClosure?(action)
    }

}
class MiddlewareMock<InputActionType, OutputActionType, StateType>: Middleware {

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

    //MARK: - handle

    var handleActionCallsCount = 0
    var handleActionCalled: Bool {
        return handleActionCallsCount > 0
    }
    var handleActionReceivedAction: InputActionType?
    var handleActionReturnValue: AfterReducer!
    var handleActionClosure: ((InputActionType) -> AfterReducer)?

    func handle(action: InputActionType) -> AfterReducer {
        handleActionCallsCount += 1
        handleActionReceivedAction = action
        return handleActionClosure.map({ $0(action) }) ?? handleActionReturnValue
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
    var dispatchReceivedAction: ActionType?
    var dispatchClosure: ((ActionType) -> Void)?

    func dispatch(_ action: ActionType) {
        dispatchCallsCount += 1
        dispatchReceivedAction = action
        dispatchClosure?(action)
    }

}
