import Foundation
import ReactiveSwift
import SwiftRex

/// An `EffectMiddleware` with no dependencies (Void) and having Input and Output Actions as the same type (`SymmetricalEffectMiddleware`).
public typealias SimpleEffectMiddleware<Action, State> = EffectMiddleware<Action, Action, State, Void>

/// An `EffectMiddleware` having Input and Output Actions as the same type.
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
///       return AnyDisposable() // Or a way to cancel the ongoing task
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
///       context.toCancel("image-for-user-\(userId)")               // alternatively you can explicitly cancel tasks by token
///       return .doNothing
///     }
///   }.inject((session: { URLSession.shared }, decoder: JSONDecoder.init))
/// ```
public final class EffectMiddleware<InputAction, OutputAction, State, Dependencies>: Middleware {
    public typealias InputActionType = InputAction
    public typealias OutputActionType = OutputAction
    public typealias StateType = State

    private var cancellables = [AnyHashable: Lifetime.Token]()
    private var cancellableButNotViaToken = CompositeDisposable()
    private var onAction: (InputActionType, StateType, Context) -> Effect<OutputActionType>
    private var dependencies: Dependencies

    public struct Context {
        public let dispatcher: ActionSource
        public let dependencies: Dependencies
        public let toCancel: (AnyHashable) -> Void
    }

    private init(
        dependencies: Dependencies,
        handle: @escaping (InputActionType, StateType, Context) -> Effect<OutputActionType>
    ) {
        self.dependencies = dependencies
        self.onAction = handle
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
            let context = Context(dispatcher: dispatcher, dependencies: self.dependencies) { [weak self] cancellingToken in
                self?.cancellables.removeValue(forKey: cancellingToken)
            }
            let effect = self.onAction(action, state, context)
            self.run(effect: effect)
        }
    }
}

extension EffectMiddleware {
    public static func onAction(
        do handler: @escaping (InputActionType, StateType, Context) -> Effect<OutputActionType>
    ) -> MiddlewareReader<Dependencies, EffectMiddleware> {
        MiddlewareReader { dependencies in
            EffectMiddleware(dependencies: dependencies, handle: handler)
        }
    }
}

extension EffectMiddleware where Dependencies == Void {
    public static func onAction(
        do handler: @escaping (InputActionType, StateType, Context) -> Effect<OutputActionType>
    ) -> EffectMiddleware<InputActionType, OutputActionType, StateType, Dependencies> {
        EffectMiddleware(dependencies: ()) { action, state, context in
            handler(action, state, context)
        }
    }
}

extension EffectMiddleware {
    private func run(effect: Effect<OutputAction>) {
        let subscription = effect
            .producer.startWithValues { [weak self] in self?.output?.dispatch($0) }

        if let token = effect.cancellationToken {
            let (lifetime, lifetimeToken) = Lifetime.make()
            lifetime += subscription
            cancellables[token] = lifetimeToken
        } else {
            cancellableButNotViaToken += subscription
        }
    }
}

extension EffectMiddleware: Semigroup {
    public static func <> (lhs: EffectMiddleware, rhs: EffectMiddleware) -> EffectMiddleware {
        Self.onAction { action, state, context -> Effect<OutputActionType> in
            let leftEffect = lhs.onAction(
                action,
                state,
                Context(
                    dispatcher: context.dispatcher,
                    dependencies: lhs.dependencies,
                    toCancel: context.toCancel
                )
            )
            let rightEffect = rhs.onAction(
                action,
                state,
                Context(
                    dispatcher: context.dispatcher,
                    dependencies: rhs.dependencies,
                    toCancel: context.toCancel
                )
            )
            // TODO: Fix cancellation on merge. The merged Publisher has no cancellation token, and once the publishers are merge they can't be
            // cancelled individually anyway. So each effect should run in the context of the own EffectMiddleware, not in the context of composed
            // middleware. To write a test for that.
            // https://github.com/SwiftRex/SwiftRex/issues/62
            return leftEffect.producer.merge(with: rightEffect.producer).asEffect
        }.inject(lhs.dependencies)
    }
}

extension EffectMiddleware: Monoid where Dependencies == Void {
    public static var identity: EffectMiddleware<InputAction, OutputAction, State, Dependencies> {
        Self.onAction { _, _, _ in .doNothing }
    }
}

extension EffectMiddleware {
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> EffectMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, Dependencies> {
        EffectMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            handle: { globalInputAction, globalState, globalContext -> Effect<GlobalOutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .doNothing }
                return self.onAction(
                    localInputAction,
                    stateMap(globalState),
                    Context(
                        dispatcher: globalContext.dispatcher,
                        dependencies: globalContext.dependencies,
                        toCancel: globalContext.toCancel
                    )
                ).producer.map(outputActionMap).asEffect
            }
        )
    }
}
