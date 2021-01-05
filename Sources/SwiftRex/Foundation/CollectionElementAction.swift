import Foundation

public struct ElementIDAction<ID: Hashable, Action> {
    public let id: ID
    public let action: Action

    public init(id: ID, action: Action) {
        self.id = id
        self.action = action
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension ElementIDAction: Identifiable { }

public struct ElementIndexAction<Index: Comparable, Action> {
    public let index: Index
    public let action: Action

    public init(index: Index, action: Action) {
        self.index = index
        self.action = action
    }
}
