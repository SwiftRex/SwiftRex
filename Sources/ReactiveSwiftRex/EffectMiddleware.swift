import Foundation
import ReactiveSwift
import SwiftRex

public typealias SymmetricalEffectMiddleware<Action, State> = EffectMiddleware<Action, Action, State>

public class EffectMiddleware<InputAction, OutputAction, State>: Middleware {
    public typealias InputActionType = InputAction
    public typealias OutputActionType = OutputAction
    public typealias StateType = State

    private var cancellables = [AnyHashable: Lifetime]()
    private var cancellableButNotViaToken = Lifetime(.init())
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
            .producer.startWithValues { [weak self] in self?.output?.dispatch($0) }

        if let token = effect.cancellationToken {
            let (lifetime, _) = Lifetime.make()
            lifetime += subscription
            cancellables[token] = lifetime
        } else {
            cancellableButNotViaToken += subscription
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
