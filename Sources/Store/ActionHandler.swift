// sourcery: AutoMockable
public protocol ActionHandler: class {
    func trigger(_ action: Action)
}
