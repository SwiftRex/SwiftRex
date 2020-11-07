#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

/// An `EffectMiddleware` with no dependencies (Void) and having Input and Output Actions as the same type (`SymmetricalEffectMiddleware`).
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public typealias SimpleEffectMiddleware<Action, State> = EffectMiddleware<Action, Action, State, Void>

/// An `EffectMiddleware` having Input and Output Actions as the same type.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public typealias SymmetricalEffectMiddleware<Action, State, Dependencies> = EffectMiddleware<Action, Action, State, Dependencies>

/// Easiest way to implement a `Middleware`, with a single function that gives you all you need, and from which you can return an `Effect`.
///
/// A `MiddlewareEffect` is a function providing an incoming `Action`, `State` and `Context` (dispatcher source, dependencies, cancellation closure)
/// and expecting as result one or multiple effects that will eventually result in outgoing actions.
///
/// An `Effect` is a publisher or observable type according to your reactive framework. It can be a one-shot effect, such as an HTTP request,
/// an observation that gives back multiple values over time, such as CoreLocation or NotificationCenter, a Timer, a pure value already known
/// or even an empty effect using the `.doNothing` constructor, if there's no need for side-effects.
/// `Effect` cannot fail, and its element/output/value type is the `OutputAction` generic of this middleware. The purpose is running tasks,
/// creating actions as they respond and returning these actions over time back to the Store. When the Effect completes, it should send a
/// completion event so the middleware will cleanup the resources.
///
/// Cancellation: effects can optionally provide a cancellation token, which can be any hashable value. If another effect arrives in the same
/// middleware instance having the very same cancellation token, the previous effect will be cancelled and replaced by the new one. This is
/// useful in case you want to keep only the last request of certain kind running, but cancel any previous ongoing request when a new is
/// dispatched. You can also explicitly cancel one or many effects at any point. For that, you will be given a `toCancel` closure during every
/// action arrival within the `Context` (third parameter). Feel free to call cancellation at that point or even later, if you hold this `toCancel`
/// closure.
///
/// Examples
///
/// Using Promises
/// ```
/// let someMiddleware = EffectMiddleware<ApiRequestAction, ApiResponseAction, SomeState, Void>.onAction { action, state, context in
///   switch action {
///   case .users:
///     return .promise { completion in
///       DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
///         completion(ApiResponseAction.someResponse("42"))
///       }
///     }
///   case .somethingIDontCare:
///     return .doNothing
///   }
/// }
/// ```
///
/// From Publisher
/// ```
/// typealias ApiFetchMiddlewareDependencies = (session: @escaping () -> URLSession, decoder: @escaping () -> JSONDecoder)
///
/// let apiFetchMiddleware =
///   EffectMiddleware<ApiRequestAction, ApiResponseAction, SomeState, ApiFetchMiddlewareDependencies>.onAction { action, state, context in
///     switch action {
///     case .users:
///       return context.dependencies.urlSession
///         .dataTaskPublisher(for: fetchAllUsersURL())
///         .map { data, _ in data }
///         .decode(type: [User].self, decoder: context.dependencies)
///         .map { users in ApiResponseAction.gotUserList(users) }
///         .replaceError(with: ApiResponseAction.errorRetrivingUserList)
///         .asEffect
///     case .user(id: UUID):
///       // ..
///     case .somethingIDontCare:
///       return .doNothing
///     }
///   }.inject((session: { URLSession.shared }, decoder: JSONDecoder.init))
/// ```
///
/// Cancellation
/// ```
/// typealias ApiFetchMiddlewareDependencies = (session: @escaping () -> URLSession, decoder: @escaping () -> JSONDecoder)
///
/// let apiFetchMiddleware =
///   EffectMiddleware<ApiRequestAction, ApiResponseAction, SomeState, ApiFetchMiddlewareDependencies>.onAction { action, state, context in
///     switch action {
///     case let .userPicture(userId):
///       return context.dependencies.urlSession
///         .dataTaskPublisher(for: fetchPicture())
///         .map { data, _ in ApiResponseAction.gotUserPicture(id: userId, data: data) }
///         .replaceError(with: ApiResponseAction.errorRetrivingUserPicture(id: userId))
///         .asEffect(cancellationToken: "image-for-user-\(userId)") // this will automatically cancel any pending download for the same image
///                                                                  // using the URL would also be possible
///     case let .cancelImageDownload(userId):
///       return context.toCancel("image-for-user-\(userId)")        // alternatively you can explicitly cancel tasks by token
///     }
///   }.inject((session: { URLSession.shared }, decoder: JSONDecoder.init))
/// ```
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public final class EffectMiddleware<InputActionType, OutputActionType, StateType, Dependencies>: Middleware {
    private var cancellables = [Int: AnyCancellable]()
    private var cancellableButNotViaToken = Set<AnyCancellable>()
    private var getState: GetState<StateType>?
    private var output: AnyActionHandler<OutputActionType>?
    fileprivate let onReceiveContext: (@escaping GetState<StateType>, AnyActionHandler<OutputActionType>) -> Void
    let onAction: (InputActionType, ActionSource, @escaping GetState<StateType>) -> Effect<Dependencies, OutputActionType>
    let dependencies: Dependencies

    init(
        dependencies: Dependencies,
        onReceiveContext: @escaping (@escaping GetState<StateType>, AnyActionHandler<OutputActionType>) -> Void,
        onAction handle: @escaping (InputActionType, ActionSource, @escaping GetState<StateType>) -> Effect<Dependencies, OutputActionType>
    ) {
        self.dependencies = dependencies
        self.onReceiveContext = onReceiveContext
        self.onAction = handle
    }

    public func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>) {
        self.getState = getState
        self.output = output
        self.onReceiveContext(getState, output)
    }

    public func handle(action: InputActionType, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        afterReducer = .do { [weak self] in
            guard let self = self, let getState = self.getState else { return }

            let effect = self.onAction(action, dispatcher, getState)
            self.runOptionalEffect(effect)
        }
    }

    func runOptionalEffect(_ effect: Effect<Dependencies, OutputActionType>) {
        guard let output = self.output,
              effect.doesSomething else { return }

        let toCancel: (AnyHashable) -> FireAndForget<DispatchedAction<OutputActionType>> = { [weak self] cancellingToken in
            .init { [weak self] in
                self?.cancellables.removeValue(forKey: cancellingToken.hashValue)
            }
        }

        let subscription = effect.run((dependencies: self.dependencies, toCancel: toCancel))?
            .sink { output.dispatch($0.action, from: $0.dispatcher) }

        if let token = effect.token {
            self.cancellables[token.hashValue] = subscription
        } else {
            subscription?.store(in: &self.cancellableButNotViaToken)
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware {
    public static func onAction(
        do onAction: @escaping (InputActionType, ActionSource, @escaping GetState<StateType>) -> Effect<Dependencies, OutputActionType>
    ) -> MiddlewareReader<Dependencies, EffectMiddleware> {
        MiddlewareReader { dependencies in
            EffectMiddleware(dependencies: dependencies, onReceiveContext: { _, _ in }, onAction: onAction)
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware where Dependencies == Void {
    public static func onAction(
        do onAction: @escaping (InputActionType, ActionSource, @escaping GetState<StateType>) -> Effect<Dependencies, OutputActionType>
    ) -> EffectMiddleware<InputActionType, OutputActionType, StateType, Dependencies> {
        EffectMiddleware(dependencies: (), onReceiveContext: { _, _ in }, onAction: onAction)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware: Semigroup {
    public static func <> (lhs: EffectMiddleware, rhs: EffectMiddleware) -> EffectMiddleware {
        EffectMiddleware(
            dependencies: lhs.dependencies,
            onReceiveContext: { getState, output in
                lhs.receiveContext(getState: getState, output: output)
                rhs.receiveContext(getState: getState, output: output)
            },
            onAction: { action, dispatcher, getState in
                let leftEffect: Effect<Dependencies, OutputActionType> = lhs.onAction(
                    action,
                    dispatcher,
                    getState
                )

                lhs.runOptionalEffect(leftEffect)

                let rightEffect: Effect<Dependencies, OutputActionType> = rhs.onAction(
                    action,
                    dispatcher,
                    getState
                )

                rhs.runOptionalEffect(rightEffect)

                return .doNothing
            }
        )
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware: Monoid where Dependencies == Void {
    public static var identity: EffectMiddleware<InputActionType, OutputActionType, StateType, Dependencies> {
        Self.onAction { _, _, _ in .doNothing }
    }
}

#endif
