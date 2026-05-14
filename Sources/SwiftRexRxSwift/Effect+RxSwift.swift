@preconcurrency import RxSwift
import SwiftRex

private struct Unchecked<T>: @unchecked Sendable { let value: T }

// MARK: - Infallible (RxSwift 6+)
//
// `Infallible<Element>` cannot error — equivalent to `Publisher<E, Never>`.
//
//   Case A   Infallible<Action>               .asEffect(scheduling:)
//   Case A2  Infallible<DispatchedAction<A>>  .asEffect(scheduling:)   — forwarding
//   Case B   Infallible<Output>               .asEffect(_ transform:scheduling:)

extension InfallibleType {
    /// Bridges an `Infallible<Action>` to `Effect<Action>`.
    public func asEffect(
        scheduling: EffectScheduling = .immediately,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Element> where Element: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Element>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext: { send(DispatchedAction($0, dispatcher: source)) },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges an `Infallible<DispatchedAction<Action>>`, forwarding the existing dispatcher.
    public func asEffect<Action: Sendable>(
        scheduling: EffectScheduling = .immediately
    ) -> Effect<Action> where Element == DispatchedAction<Action> {
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext: { send($0) },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges an `Infallible<Output>` to `Effect<Action>` by mapping each element.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Element) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext: { send(DispatchedAction(transform($0), dispatcher: source)) },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }
}

// MARK: - Observable (failable)
//
//   Case A   Observable<Action>               .asEffect(scheduling:)           — errors discarded
//   Case A2  Observable<DispatchedAction<A>>  .asEffect(scheduling:)           — forwarding
//   Case B   Observable<Output>               .asEffect(_ transform:scheduling:) — errors discarded
//   Case C   Observable<Output>               .asEffect(_ transform:scheduling:) — Result

extension ObservableType {
    /// Bridges an `Observable<Action>` to `Effect<Action>`. Errors are silently discarded.
    public func asEffect(
        scheduling: EffectScheduling = .immediately,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Element> where Element: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Element>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext:      { send(DispatchedAction($0, dispatcher: source)) },
                    onError:     { _ in complete() },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges an `Observable<DispatchedAction<Action>>`, forwarding the existing dispatcher.
    /// Errors are silently discarded.
    public func asEffect<Action: Sendable>(
        scheduling: EffectScheduling = .immediately
    ) -> Effect<Action> where Element == DispatchedAction<Action> {
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext:      { send($0) },
                    onError:     { _ in complete() },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges an `Observable<Output>` to `Effect<Action>` by mapping each element.
    /// Errors are silently discarded.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Element) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext:      { send(DispatchedAction(transform($0), dispatcher: source)) },
                    onError:     { _ in complete() },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges an `Observable<Output>` to `Effect<Action>` via Result. Errors are delivered
    /// as `.failure` then `complete()` fires.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Result<Element, Error>) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext:      { send(DispatchedAction(transform(.success($0)), dispatcher: source)) },
                    onError:     { error in
                        send(DispatchedAction(transform(.failure(error)), dispatcher: source))
                        complete()
                    },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }
}

// MARK: - Fire and forget (RxSwift)

extension Effect {
    /// Subscribes to an `Observable`, ignoring all elements and errors, completing when done.
    /// Use with `|>`: `myObservable |> Effect.fireAndForget`.
    public static func fireAndForget<O: ObservableType>(_ o: O) -> Self {
        let o = Unchecked(value: o)
        return Effect(components: [
            Component(subscribe: { _, complete in
                let d = o.value.subscribe(
                    onNext:      { _ in },
                    onError:     { _ in complete() },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: .immediately)
        ])
    }

    /// Subscribes to an `Infallible`, ignoring all elements, completing when done.
    /// Use with `|>`: `myInfallible |> Effect.fireAndForget`.
    public static func fireAndForget<I: InfallibleType>(_ i: I) -> Self {
        let i = Unchecked(value: i)
        return Effect(components: [
            Component(subscribe: { _, complete in
                let d = i.value.subscribe(
                    onNext:      { _ in },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: .immediately)
        ])
    }
}

