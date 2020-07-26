import Foundation

public struct ElementIDAction<ID: Hashable, Action> {
    public let id: ID
    public let action: Action

    public init(id: ID, action: Action) {
        self.id = id
        self.action = action
    }
}

public struct ElementIndexAction<Index: Comparable, Action> {
    public let index: Index
    public let action: Action

    public init(index: Index, action: Action) {
        self.index = index
        self.action = action
    }
}
