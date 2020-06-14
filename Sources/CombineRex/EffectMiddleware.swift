#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public typealias SymmetricalEffectMiddleware<Action, State> = EffectMiddleware<Action, Action, State>

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public class EffectMiddleware<InputAction, OutputAction, State>: Middleware {
    public typealias InputActionType = InputAction
    public typealias OutputActionType = OutputAction
    public typealias StateType = State

    private var cancellables = [AnyHashable: AnyCancellable]()
    private var cancellableButNotViaToken = Set<AnyCancellable>()
    private var onAction: ((InputActionType, StateType, ActionSource) -> Void)?

    public init(handle: @escaping (InputActionType, StateType, ActionSource, (AnyHashable) -> Void) -> Effect<OutputActionType>) {
        self.onAction = { [weak self] action, state, actionSource in
            self?.run(effect:
                handle(action, state, actionSource) { [weak self] toCancel in
                    self?.cancellables.removeValue(forKey: toCancel)
                }
            )
        }
    }

    public init(handle: @escaping (InputActionType, StateType, (AnyHashable) -> Void) -> Effect<OutputActionType>) {
        self.onAction = { [weak self] action, state, _ in
            self?.run(effect:
                handle(action, state) { [weak self] toCancel in
                    self?.cancellables.removeValue(forKey: toCancel)
                }
            )
        }
    }

    public init(handle: @escaping (InputActionType, StateType, ActionSource) -> Effect<OutputActionType>) {
        self.onAction = { [weak self] action, state, actionSource in
            self?.run(effect: handle(action, state, actionSource))
        }
    }

    public init(handle: @escaping (InputActionType, StateType) -> Effect<OutputActionType>) {
        self.onAction = { [weak self] action, state, actionSource in
            self?.run(effect: handle(action, state))
        }
    }

    private func run(effect: Effect<OutputAction>) {
        let subscription = effect
            .sink(receiveValue: { [weak self] in self?.output?.dispatch($0) })

        if let token = effect.cancellationToken {
            cancellables[token] = subscription
        } else {
            subscription.store(in: &cancellableButNotViaToken)
        }
    }

    private var getState: GetState<StateType>?
    private var output: AnyActionHandler<OutputActionType>?
    public func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>) {
        self.getState = getState
        self.output = output
    }

    public func handle(action: InputActionType, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        afterReducer = .do { [weak self] in
            guard let state = self?.getState?() else { return }
            self?.onAction?(action, state, dispatcher)
        }
    }
}
#endif
