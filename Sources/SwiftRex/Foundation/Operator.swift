/**
 Pipe forward application operator
 |>

 Apply function
 - Left: value a: A
 - Right: function A to B
 - Return: value b: B

 * left associativity
 * precedence group: Forward Application
 */
infix operator |>: ForwardApplication
precedencegroup ForwardApplication {
    associativity: left
    higherThan: AssignmentPrecedence
}

/**
 Forward composition operator / Right arrow operator
 >>>

 Compose two functions when output of the left matches input type of the right
 - Left: function A to B
 - Right: function B to C
 - Return: function A to C

 * left associativity
 * precedence group: Forward Composition
 * Forward Composition > Forward Application
 */
infix operator >>>: ForwardComposition
precedencegroup ForwardComposition {
    associativity: left
    higherThan: ForwardApplication
}

/**
 Single type compose operator / Diamond operator
 <>

 1) Compose two functions with same signature from A to A, and merges them into a new function from A to A, or in other words it's a forward composition where A, B and C are of the same type
 - Left: function A to A
 - Right: function A to A
 - Return: function A to A

 2) Compose two functions with same signature from in/out A to Void, and merges them into a new function from in/out A to Void, or in other words it's the same as previous operation but with in/out A to Void instead of A to A
 - Left: function inout A to Void
 - Right: function inout A to Void
 - Return: function inout A to Void

 * left associativity
 * precedence group: Single Type Composition
 * Single Type Composition > Forward Application
 */
infix operator <>: MonoidAppend
precedencegroup MonoidAppend {
    associativity: left
    higherThan: ForwardComposition
}
