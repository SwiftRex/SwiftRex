public class SubstateMiddleware<Whole, PartMiddleware: Middleware>: Middleware {
    typealias Part = PartMiddleware.StateType
    public var actionHandler: ActionHandler? {
        get {
            return partMiddleware.actionHandler
        }
        set {
            partMiddleware.actionHandler = newValue
        }
    }

    private let partMiddleware: PartMiddleware
    private let stateConverter: (@escaping GetState<Whole>) -> GetState<Part>

    init(middleware: PartMiddleware, stateConverter: @escaping (@escaping GetState<Whole>) -> GetState<Part>) {
        self.partMiddleware = middleware
        self.stateConverter = stateConverter
    }

    public func handle(event: EventProtocol, getState: @escaping GetState<Whole>, next: @escaping NextEventHandler<Whole>) {
        let getPartState = stateConverter(getState)
        let getPartNext: NextEventHandler<Part> = { event, _ in
            next(event, getState)
        }
        partMiddleware.handle(event: event, getState: getPartState, next: getPartNext)
    }

    public func handle(action: ActionProtocol, getState: @escaping GetState<Whole>, next: @escaping NextActionHandler<Whole>) {
        let getPartState = stateConverter(getState)
        let getPartNext: NextActionHandler<Part> = { action, _ in
            next(action, getState)
        }
        partMiddleware.handle(action: action, getState: getPartState, next: getPartNext)
    }
}

extension Middleware {
    public func lift<Whole>(_ substatePath: WritableKeyPath<Whole, StateType>) -> SubstateMiddleware<Whole, Self> {
        return SubstateMiddleware<Whole, Self>(middleware: self) { getWholeState in
            return {
                let wholeState = getWholeState()
                return wholeState[keyPath: substatePath]
            }
        }
    }
}
