import Foundation

public struct ElementIDAction<ID: Hashable, Action> {
    public let id: ID
    public let action: Action

    public init(id: ID, action: Action) {
        self.id = id
        self.action = action
    }
}

extension ElementIDAction: Decodable where ID: Decodable, Action: Decodable { }
extension ElementIDAction: Encodable where ID: Encodable, Action: Encodable { }
extension ElementIDAction: Equatable where Action: Equatable { }
extension ElementIDAction: Hashable where Action: Hashable { }

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

extension ElementIndexAction: Decodable where Index: Decodable, Action: Decodable { }
extension ElementIndexAction: Encodable where Index: Encodable, Action: Encodable { }
extension ElementIndexAction: Equatable where Index: Equatable, Action: Equatable { }
extension ElementIndexAction: Hashable where Index: Hashable, Action: Hashable { }
