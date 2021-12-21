import Foundation

public struct IO<OutputActionType> {
    private let runIO: (AnyActionHandler<OutputActionType>) -> Void

    public init(_ run: @escaping (AnyActionHandler<OutputActionType>) -> Void) {
        self.runIO = run
    }

    public static func pure() -> IO {
        IO { _ in }
    }

    public func run(_ output: AnyActionHandler<OutputActionType>) {
        runIO(output)
    }

    public func run (_ output: @escaping (DispatchedAction<OutputActionType>) -> Void) {
        runIO(.init(output))
    }
}

extension IO: Monoid {
    public static var identity: IO { .pure() }
}

public func <> <OutputActionType>(lhs: IO<OutputActionType>, rhs: IO<OutputActionType>) -> IO<OutputActionType> {
    .init { handler in
        lhs.run(handler)
        rhs.run(handler)
    }
}

extension IO {
    public func map<B>(_ transform: @escaping (OutputActionType) -> B) -> IO<B> {
        IO<B> { output in
            self.run(output.contramap(transform))
        }
    }
}

extension IO {
    public func flatMap<B>(_ transform: @escaping (DispatchedAction<OutputActionType>) -> IO<B>) -> IO<B> {
        IO<B> { actionHandlerB in
            self.run(.init { outputActionType in
                transform(outputActionType).run(actionHandlerB)
            })
        }
    }
}
