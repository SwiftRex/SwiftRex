#if canImport(Combine)
import Combine

extension StoreBase {
    public typealias Output = State
    public typealias Failure = Never

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        return state.receive(subscriber: subscriber)
    }
}
#endif
