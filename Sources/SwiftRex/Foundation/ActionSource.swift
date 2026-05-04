/// The call-site origin of a dispatched action, captured automatically at every public API boundary.
///
/// Every `dispatch` call and every `Effect` factory captures `#file`, `#function`, and `#line` via
/// default parameter values, so callers never need to construct this explicitly.
public struct ActionSource: Hashable, Sendable {
    public let file: String
    public let function: String
    public let line: UInt
    public let info: String?

    public init(
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        info: String? = nil
    ) {
        self.file = file
        self.function = function
        self.line = line
        self.info = info
    }
}
