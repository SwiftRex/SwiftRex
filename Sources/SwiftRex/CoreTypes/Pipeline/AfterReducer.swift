import Foundation

public struct AfterReducer: Monoid {
    public static let identity: AfterReducer = doNothing()

    let reducerIsDone: () -> Void
    private init(run: @escaping () -> Void) {
        self.reducerIsDone = run
    }

    public static func `do`(_ run: @escaping () -> Void) -> AfterReducer {
        .init(run: run)
    }

    public static func doNothing() -> AfterReducer {
        .init(run: { })
    }
}

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
    public func asAfterReducer() -> AfterReducer {
        AfterReducer.do {
            Array(self).reversed().forEach { $0.reducerIsDone() }
        }
    }
}
