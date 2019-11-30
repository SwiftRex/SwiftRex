/**
Protocol for a semigroup, any algebraic structure that allows two of its elements to be combined into one,
`(A, A) -> A`, for any of its elements and keeping associativity property for all the cases, for example:
`(a1 <> a2) <> a3 = a1 <> (a2 <> a3)` for any `a`s in `A`.

Axioms:
 - Totality
 - Associativity

For example, having a `f(x) -> x` and a `g(x) -> x`, one would be able to compose `h = f <> g` in a way that the new
function `h(x)` will be similar to `g(f(x))`
*/
public protocol Semigroup {
    /**
     Semigroup combine operation

     - Parameters:
       - lhs: First semigroup `(A) -> A`, let's call it `f(x)`
       - rhs: Second semigroup `(A) -> A`, let's call it `g(x)`
     - Returns: a composed semigroup `(A) -> A` equivalent to `g(f(x))`
     */
    static func <> (lhs: Self, rhs: Self) -> Self
}

/**
Protocol for a monoid algebra, allowing monoidal composition. It's a `Semigroup` with identity element, element which,
when combined to any other element, will keep the other elemenet unchanged, regardless if the composition happened from
the left or from the right, for example: `a <> identity = identity <> a = a`, for any `a` in `A`.

Axioms:
 - Totality
 - Associativity
 - Identity

For example, having a `f(x) -> x` and a `g(x) -> x`, one would be able to compose `h = f <> g` in a way that the new
function `h(x)` will be similar to `g(f(x))`, and there should be a function `i(x)` where `i`, when composed to any
other function, will not change the result: `f <> i = i <> f = f`, for `f`, `g`, `h` and all other endo-functions.
*/
public protocol Monoid: Semigroup {
    /**
     Neutral monoidal container. Composing any monoid with an identity monoid should result in a function unchanged, regardless if the empty element is on the left-hand side or the right-hand side.

     Therefore, `f(x) <> identity == f(x) == identity <> f(x)`
     */
    static var identity: Self { get }
}
