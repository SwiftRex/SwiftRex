precedencegroup ForwardApplication {
    associativity: left
}

infix operator |>: ForwardApplication

precedencegroup ForwardComposition {
    associativity: left
    higherThan: ForwardApplication
}

infix operator >>>: ForwardComposition

precedencegroup MonoidAppend {
    associativity: left
}

infix operator <>: MonoidAppend

public protocol Monoid {
    static var empty: Self { get }
    static func <> (lhs: Self, rhs: Self) -> Self
}
