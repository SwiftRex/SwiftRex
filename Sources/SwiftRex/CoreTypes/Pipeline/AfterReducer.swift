import Foundation

/// Wraps a closure that will be called after the Reducer pipeline has changed the state with the current action.
/// With this structure, a middleware can schedule some callback to be executed with the new state, and evidently access this state to check what's
/// different. This can be very useful for Middlewares that perform logging, monitoring or telemetry, so you can check the state before and after
/// reducers' execution, or how much time it took for the whole chain to be called (in case this middleware is the first in the chain, of course).
/// `AfterReducer` is a monoid, that means it can be combined with another `AfterReducer` to form a new one (that executes both operations in the
/// reverse order) and an identity instance, that when combined with any other `AfterReducer` changes nothing in the result, acting as a neutral
/// element in composition. The identity of an `AfterReducer` is the static instance `doNothing()`, that contains an empty closure for no-op.
/// The combination between two `AfterReducer` instances occur in reverse order so the first middleware will have its "after reducer" closure executed
/// last. This composition can be achieved by using the operator `<>`
public struct AfterReducer: Monoid {
    /// The identity of an `AfterReducer` is the static instance `doNothing()`, that contains an empty closure for no-op.
    /// When combined with any other `AfterReducer` changes nothing in the result, acting as a neutral element in composition.
    public static let identity: AfterReducer = doNothing()

    /// Execute the operation scheduled by the middleware. It should run only once and right after Reducer chain has finished and new state is
    /// published
    let reducerIsDone: () -> Void

    private init(run: @escaping () -> Void) {
        self.reducerIsDone = run
    }

    /// Schedules some task to be executed right after Reducer chain has finished and new state is published
    public static func `do`(_ run: @escaping () -> Void) -> AfterReducer {
        .init(run: run)
    }

    /// The identity of an `AfterReducer` is the static instance `doNothing()`, that contains an empty closure for no-op.
    /// When combined with any other `AfterReducer` changes nothing in the result, acting as a neutral element in composition.
    public static func doNothing() -> AfterReducer {
        .init(run: { })
    }
}

/// The combination between two `AfterReducer` instances occur in reverse order so the first middleware will have its "after reducer" closure executed
/// last. This composition can be achieved by using the operator `<>`.
public func <> (lhs: AfterReducer, rhs: AfterReducer) -> AfterReducer {
    AfterReducer.do {
        // When composing multiple closures that run after reducer, compose them backwards
        // so the middlewares execute post-reducer in the reverse order as they run pre-reducer
        // e.g. (1) -> (2) -> (3) -> reducer -> (3) -> (2) -> (1)
        //      == pre-reducer ==               == post-reducer ==
        rhs.reducerIsDone()
        lhs.reducerIsDone()
    }
}

extension Collection where Element == AfterReducer {
    /// Reduces a collection of `AfterReducer` closures into a single `AfterReducer` closure. Useful when a group of middlewares ran, we collected
    /// their `AfterReducer` operations in an Array and now we want to merge everything into a single `AfterReducer` closure to execute all of them
    /// once the reducer pipeline has finished and new state is published.
    /// The composition will happen in the reversed order of the closures in the array, because we want the first middleware to be the last notified
    /// after reducer.
    public func asAfterReducer() -> AfterReducer {
        AfterReducer.do {
            Array(self).reversed().forEach { $0.reducerIsDone() }
        }
    }
}
