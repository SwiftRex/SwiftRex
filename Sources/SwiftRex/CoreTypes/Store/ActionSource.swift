/// Representation of the entity responsible for creating and dispatching the action, including information useful for logging, debugging, analytics
/// or monitoring. The action source will be implicitly created when `ActionHandler.dispatch` is called from a middleware, view or presenter, and
/// it will contain the file, function and line from where the dispatch function was called. Additionally you can append extra information useful
/// for debugging, as an optional String attached to the ActionSource.
///
/// The Action Source will arrive at every middleware's `handle` function, and you have the opportunity to use this information when performing side-
/// effects, such as printing logs.
public struct ActionSource: Codable, Equatable {
    /// File that created and dispatched the action
    public let file: String

    /// Function that created and dispatched the action
    public let function: String

    /// Line in the file where the action was created and dispatched
    public let line: UInt

    /// Additional information about the moment where the action was dispatched. This is an optional String that can hold information useful for
    /// debugging, logging, monitoring or analytics.
    public let info: String?

    /// Creates a structure that holds information about the entity who created and dispatched the action.
    /// - Parameters:
    ///   - file: File that created and dispatched the action
    ///   - function: Function that created and dispatched the action
    ///   - line: Line in the file where the action was created and dispatched
    ///   - info: Additional information about the moment where the action was dispatched. This is an optional String that can hold information
    ///           useful for debugging, logging, monitoring or analytics.
    public init(file: String, function: String, line: UInt, info: String?) {
        self.file = file
        self.function = function
        self.line = line
        self.info = info
    }
}

extension ActionSource {
    public static func here(file: String = #file, function: String = #function, line: UInt = #line, info: String? = nil) -> ActionSource {
        .init(file: file, function: function, line: line, info: info)
    }
}
