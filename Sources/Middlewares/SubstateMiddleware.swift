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
    /**
     A lenses method. The global state of your app is *Whole*, and the `Middleware` handles *Part*, that is a sub-state.
     So for example you may want to have a `GPSMiddleware` that knows about the following `struct`:
     ```
     struct Location {
        let latitude: Double
        let longitude: Double
     }
     ```

     Let's call it `Part`. Both, this state and its middleware will be part of an external framework, used by dozens of apps. Internally probably the `Middleware` will use `CoreLocation` to fetch the GPS changes, and triggers some actions. On the main app we have a global state, that we now call `Whole`.

     ```
     struct MyGlobalState {
        let title: String?
        let listOfItems: [Item]
        let currentLocation: Location
     }
     ```

     As expected, `Part` is a property of `Whole`, maybe not directly, it could be several nodes deep in the tree.

     Because our `Store` understands `Whole` and our `GPSMiddleware` understands `Part`, we must `lift(_:)` the middleware to the `Whole` level, by using:

     ```
     let globalStateMiddleware = gpsMiddleware.lift(\MyGlobalState.currentLocation)
     ```

     Now this middleware can be used within our `Store` or even composed with others. It also can be used in other apps as long as we have a way to lift it to the world of `Whole`.

     - Parameter substatePath: the keyPath that goes from `Whole` to `Part`
     - Returns: a `SubstateMiddleware``<Whole, Self>` that knows how to translate `Whole` to `Part` and vice-versa, by using the key path.
     */
    public func lift<Whole>(_ substatePath: WritableKeyPath<Whole, StateType>) -> SubstateMiddleware<Whole, Self> {
        return SubstateMiddleware<Whole, Self>(middleware: self) { getWholeState in
            return {
                let wholeState = getWholeState()
                return wholeState[keyPath: substatePath]
            }
        }
    }
}
