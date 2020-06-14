import Foundation
import ReactiveSwift
import SwiftRex

public typealias SimpleEffectMiddleware<Action, State> = EffectMiddleware<Action, Action, State, Void>
public typealias SymmetricalEffectMiddleware<Action, State, Dependencies> = EffectMiddleware<Action, Action, State, Dependencies>

public class EffectMiddleware<InputAction, OutputAction, State, Dependencies>: Middleware {
    public typealias InputActionType = InputAction
    public typealias OutputActionType = OutputAction
    public typealias StateType = State

    private var cancellables = [AnyHashable: Lifetime]()
    private var cancellableButNotViaToken = Lifetime(.init())
    private var onAction: ((InputActionType, StateType, ActionSource, Dependencies) -> Void)?
    private var dependencies: Dependencies!

    public init(
        dependencies: Dependencies,
        handle: @escaping (InputActionType, StateType, ActionSource, Dependencies, (AnyHashable) -> Void) -> Effect<OutputActionType>
    ) {
        self.onAction = { [weak self] action, state, actionSource, dependencies in
            self?.run(effect:
                handle(action, state, actionSource, dependencies) { [weak self] toCancel in
                    self?.cancellables.removeValue(forKey: toCancel)
                }
            )
        }
    }

    public init(
        dependencies: Dependencies,
        handle: @escaping (InputActionType, StateType, Dependencies, (AnyHashable) -> Void) -> Effect<OutputActionType>
    ) {
        self.onAction = { [weak self] action, state, _, dependencies in
            self?.run(effect:
                handle(action, state, dependencies) { [weak self] toCancel in
                    self?.cancellables.removeValue(forKey: toCancel)
                }
            )
        }
    }

    public init(
        dependencies: Dependencies,
        handle: @escaping (InputActionType, StateType, ActionSource, Dependencies) -> Effect<OutputActionType>
    ) {
        self.onAction = { [weak self] action, state, actionSource, dependencies in
            self?.run(effect: handle(action, state, actionSource, dependencies))
        }
    }

    public init(
        dependencies: Dependencies,
        handle: @escaping (InputActionType, StateType, Dependencies) -> Effect<OutputActionType>
    ) {
        self.onAction = { [weak self] action, state, actionSource, dependencies in
            self?.run(effect: handle(action, state, dependencies))
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
            guard let self = self else { return }
            guard let state = self.getState?() else { return }
            self.onAction?(action, state, dispatcher, self.dependencies)
        }
    }
}

extension EffectMiddleware where Dependencies == Void {
    public convenience init(
        handle: @escaping (InputActionType, StateType, ActionSource, (AnyHashable) -> Void) -> Effect<OutputActionType>
    ) {
        self.init(dependencies: ()) { action, state, actionSource, _, toCancel in
            handle(action, state, actionSource, toCancel)
        }
    }

    public convenience init(
        handle: @escaping (InputActionType, StateType, (AnyHashable) -> Void) -> Effect<OutputActionType>
    ) {
        self.init(dependencies: ()) { action, state, _, _, toCancel in
            handle(action, state, toCancel)
        }
    }

    public convenience init(
        handle: @escaping (InputActionType, StateType, ActionSource) -> Effect<OutputActionType>
    ) {
        self.init(dependencies: ()) { action, state, actionSource, _, _ in
            handle(action, state, actionSource)
        }
    }

    public convenience init(
        handle: @escaping (InputActionType, StateType) -> Effect<OutputActionType>
    ) {
        self.init(dependencies: ()) { action, state, _, _, _ in
            handle(action, state)
        }
    }
}

extension EffectMiddleware {
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
}
