import SwiftRex

struct MonoidMiddleware<InputActionType, OutputActionType, StateType>: MiddlewareProtocol, Monoid {
    var string: String
    let mock: MiddlewareProtocolMock<InputActionType, OutputActionType, StateType>

    func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType> {
        mock.handle(action: action, from: dispatcher, state: state)
    }

    init(string: String, mock: MiddlewareProtocolMock<InputActionType, OutputActionType, StateType> = .init()) {
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
