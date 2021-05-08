import Foundation

public struct IO<OutputActionType> {
    let runIO: (AnyActionHandler<OutputActionType>) -> Void

    public init(_ run: @escaping (AnyActionHandler<OutputActionType>) -> Void) {
        self.runIO = run
    }

    public static func pure() -> IO {
        IO { _ in }
    }
}

extension IO: Monoid {
    static public var identity: IO { .pure() }
}

public func <> <OutputActionType>(lhs: IO<OutputActionType>, rhs: IO<OutputActionType>) -> IO<OutputActionType> {
    .init { handler in
        lhs.runIO(handler)
        rhs.runIO(handler)
    }
}

extension IO {
    public func map<B>(_ transform: @escaping (OutputActionType) -> B) -> IO<B> {
        IO<B> { output in
            self.runIO(output.contramap(transform))
        }
    }
}

extension IO {
    public func flatMap<B>(_ transform: @escaping (DispatchedAction<OutputActionType>) -> IO<B>) -> IO<B> {
        IO<B> { actionHandlerB in
            self.runIO(.init { outputActionType in
                transform(outputActionType).runIO(actionHandlerB)
            })
        }
    }
}
