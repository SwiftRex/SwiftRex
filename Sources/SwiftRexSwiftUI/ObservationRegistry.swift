// SPDX-License-Identifier: Apache-2.0

// The dependency registry behind `ObservableStore`: one node per key path a view has read, arranged as a tree
// that follows how paths were composed (`\.player` → `\.player.title`; `\.songs` → a row → the row's
// `title`). Only the **live** part of the tree is kept — dependencies read since they last fired, and the
// ancestors leading to them — and a diff walks it top-down, descending only into subtrees whose root
// changed. One `==` on an unchanged collection skips every row beneath it, so a change costs time in
// proportion to what changed, not to how much is being watched.

/// One recorded dependency.
@MainActor
final class ObservationDependency<Owner: AnyObject, State> {
    /// Whether the value at this path differs between two states (`!=` when `Equatable`, else always).
    let changed: (State, State) -> Bool
    /// The dependency on the path this one extends — when that one is unchanged, so is this.
    let parent: ObservationDependency?
    /// Registrar hooks (Observation strategy only).
    let access: ((Owner) -> Void)?
    let willSet: ((Owner) -> Void)?
    let didSet: ((Owner) -> Void)?

    /// Read since it last fired — a view is waiting on it.
    var armed = false
    /// Part of the live tree: armed itself, or an ancestor of something armed.
    var attached = false
    var children: [ObservationDependency] = []

    init(
        changed: @escaping (State, State) -> Bool,
        parent: ObservationDependency?,
        access: ((Owner) -> Void)?,
        willSet: ((Owner) -> Void)?,
        didSet: ((Owner) -> Void)?
    ) {
        self.changed = changed
        self.parent = parent
        self.access = access
        self.willSet = willSet
        self.didSet = didSet
    }
}

/// The live dependency tree.
@MainActor
final class ObservationRegistry<Owner: AnyObject, State> {
    typealias Dependency = ObservationDependency<Owner, State>

    private var roots: [Dependency] = []
    private(set) var armedCount = 0

    var isEmpty: Bool { roots.isEmpty }

    /// Marks `dependency` as awaited, attaching it (and its ancestors) to the live tree.
    func arm(_ dependency: Dependency) {
        guard !dependency.armed else { return }
        dependency.armed = true
        armedCount += 1
        attach(dependency)
    }

    /// The armed dependencies that changed between `old` and `new`, now disarmed. Subtrees whose root didn't
    /// change aren't visited; subtrees left with nothing armed are detached.
    func diff(_ old: State, _ new: State) -> [Dependency] {
        var fired: [Dependency] = []
        roots = roots.filter { visit($0, old, new, &fired) }
        return fired
    }

    /// Disarms everything — the Combine strategy: one signal re-renders every observing view, which re-reads.
    func disarmAll() {
        roots.forEach(clear)
        roots.removeAll(keepingCapacity: true)
        armedCount = 0
    }

    private func attach(_ dependency: Dependency) {
        guard !dependency.attached else { return }
        dependency.attached = true
        if let parent = dependency.parent {
            parent.children.append(dependency)
            attach(parent)
        } else {
            roots.append(dependency)
        }
    }

    private func visit(_ dependency: Dependency, _ old: State, _ new: State, _ fired: inout [Dependency]) -> Bool {
        guard dependency.changed(old, new) else { return true }
        if dependency.armed {
            dependency.armed = false
            armedCount -= 1
            fired.append(dependency)
        }
        dependency.children = dependency.children.filter { visit($0, old, new, &fired) }
        dependency.attached = dependency.armed || !dependency.children.isEmpty
        return dependency.attached
    }

    private func clear(_ dependency: Dependency) {
        dependency.children.forEach(clear)
        dependency.children.removeAll()
        dependency.armed = false
        dependency.attached = false
    }
}
