#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public typealias SimpleEffectMiddleware<Action, State> = EffectMiddleware<Action, Action, State, Void>

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public typealias SymmetricalEffectMiddleware<Action, State, Dependencies> = EffectMiddleware<Action, Action, State, Dependencies>

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public class EffectMiddleware<InputAction, OutputAction, State, Dependencies>: Middleware {
    public typealias InputActionType = InputAction
    public typealias OutputActionType = OutputAction
    public typealias StateType = State

    private var cancellables = [AnyHashable: AnyCancellable]()
    private var cancellableButNotViaToken = Set<AnyCancellable>()
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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware {
    private func run(effect: Effect<OutputAction>) {
        let subscription = effect
            .sink(receiveValue: { [weak self] in self?.output?.dispatch($0) })

        if let token = effect.cancellationToken {
            cancellables[token] = subscription
        } else {
            subscription.store(in: &cancellableButNotViaToken)
        }
    }
}
#endif
