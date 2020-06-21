import SwiftRex

struct MonoidMiddleware<InputActionType, OutputActionType, StateType>: Middleware, Monoid {
    var string: String
    let mock: MiddlewareMock<InputActionType, OutputActionType, StateType>

    func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>) {
        mock.receiveContext(getState: getState, output: output)
    }

    func handle(action: InputActionType, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        mock.handle(action: action, from: dispatcher, afterReducer: &afterReducer)
    }

    init(string: String, mock: MiddlewareMock<InputActionType, OutputActionType, StateType> = .init()) {
        self.string = string
        self.mock = mock
    }

    static var identity: MonoidMiddleware {
        .init(string: "")
    }

    static func <> (lhs: MonoidMiddleware, rhs: MonoidMiddleware) -> MonoidMiddleware {
        MonoidMiddleware(string: lhs.string + rhs.string,
                         mock: lhs.mock <> rhs.mock)
    }
}
