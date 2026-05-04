import CoreFP

/// Packages everything a reducer needs to operate on a single element inside a container:
/// a pre-composed traversal from the global state root to the element, plus the local action.
///
/// `Root` is the global state type, `Element` is the element the local reducer operates on,
/// and `SubAction` is the local action type. `elementInRoot` is the composition of the
/// container's key path with an element-selection traversal — built once at dispatch time,
/// carried through the action.
///
/// **Typical dispatch:**
/// ```swift
/// // Identifiable element in a MutableCollection:
/// store.send(.updateItem(CollectionAction(\.items, id: item.id, action: .toggleDone)))
///
/// // Using an ix traversal explicitly:
/// store.send(.updateItem(CollectionAction(\.items, element: [Item].ix(id: item.id), action: .toggleDone)))
///
/// // Index-based:
/// store.send(.expandSection(CollectionAction(\.sections, index: 2, action: .expand)))
///
/// // Dictionary:
/// store.send(.updateConfig(CollectionAction(\.configs, key: "debug", action: .toggle)))
/// ```
///
/// **Reducer side — one-sided lift:**
/// ```swift
/// itemReducer.liftCollection(action: \.updateItem)
/// ```
public struct CollectionAction<Root, Element, SubAction> {
    public let elementInRoot: AffineTraversal<Root, Element>
    public let action: SubAction

    /// Primary initialiser — supply a pre-composed `AffineTraversal<Root, Element>` directly.
    /// Use this when the element lookup requires custom logic beyond the `ix` family.
    public init(_ elementInRoot: AffineTraversal<Root, Element>, action: SubAction) {
        self.elementInRoot = elementInRoot
        self.action = action
    }
}

// MARK: - Convenience initialisers

extension CollectionAction {
    /// Composes a container key path with an element traversal from the `ix` family (or any
    /// `AffineTraversal<C, Element>`).
    ///
    /// ```swift
    /// CollectionAction(\.items, element: [Item].ix(id: item.id), action: .toggleDone)
    /// CollectionAction(\.items, element: [Item].ix(0),           action: .expand)
    /// CollectionAction(\.dict,  element: [String: V].ix(key: k), action: .update)
    /// ```
    public init<C>(
        _ collectionPath: WritableKeyPath<Root, C>,
        element: AffineTraversal<C, Element>,
        action: SubAction
    ) {
        self.init(
            AffineTraversal<Root, Element>(
                preview: { element.preview($0[keyPath: collectionPath]) },
                set: { root, elem in
                    var copy = root
                    copy[keyPath: collectionPath] = element.set(root[keyPath: collectionPath], elem)
                    return copy
                }
            ),
            action: action
        )
    }

    /// Locates the element by its `Identifiable.id` inside a `MutableCollection`.
    /// Internally uses `C.ix(id:)` from the FP library.
    public init<C: MutableCollection>(
        _ collectionPath: WritableKeyPath<Root, C>,
        id: Element.ID,
        action: SubAction
    ) where C.Element == Element, Element: Identifiable {
        self.init(collectionPath, element: C.ix(id: id), action: action)
    }

    /// Locates the element by a custom `Hashable` identifier inside a `MutableCollection`.
    public init<C: MutableCollection, ID: Hashable>(
        _ collectionPath: WritableKeyPath<Root, C>,
        id: ID,
        identifier: KeyPath<Element, ID>,
        action: SubAction
    ) where C.Element == Element {
        self.init(
            collectionPath,
            element: AffineTraversal<C, Element>(
                preview: { $0.first(where: { $0[keyPath: identifier] == id }) },
                set: { col, elem in
                    guard let idx = col.firstIndex(where: { $0[keyPath: identifier] == id })
                    else { return col }
                    var copy = col
                    copy[idx] = elem
                    return copy
                }
            ),
            action: action
        )
    }

    /// Locates the element by its index inside a `MutableCollection`.
    /// Internally uses `C.ix(_:)` from the FP library.
    public init<C: MutableCollection>(
        _ collectionPath: WritableKeyPath<Root, C>,
        index: C.Index,
        action: SubAction
    ) where C.Element == Element {
        self.init(collectionPath, element: C.ix(index), action: action)
    }

    /// Locates the value by its key inside a `Dictionary`.
    /// Internally uses `[Key: Element].ix(key:)` from the FP library.
    public init<Key: Hashable>(
        _ dictionaryPath: WritableKeyPath<Root, [Key: Element]>,
        key: Key,
        action: SubAction
    ) {
        self.init(dictionaryPath, element: [Key: Element].ix(key: key), action: action)
    }
}
