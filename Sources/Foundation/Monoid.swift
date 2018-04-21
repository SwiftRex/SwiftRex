/**
 Protocol for a monoid container, allowing monoidal composition

 For example, having a `f(x) -> x` and a `g(x) -> x`, one would be able to compose `h = f <> g` in a way that the new function `h(x)` will be similar to `g(f(x))`
 */
public protocol Monoid {

    /**
     Neutral monoidal container. Composing any monoid with an empty monoid should result in a function unchanged, regardless if the empty element is on the left-hand side or the right-hand side.

     Therefore, `f(x) <> empty == f(x) == empty <> f(x)`
     */
    static var empty: Self { get }

    /**
     Monoid Append operation

     - Parameters:
       - lhs: First monoid `(A) -> A`, let's call it `f(x)`
       - rhs: Second monoid `(A) -> A`, let's call it `g(x)`
     - Returns: a composed monoid `(A) -> A` equivalent to `g(f(x))`
     */
    static func <> (lhs: Self, rhs: Self) -> Self
}
