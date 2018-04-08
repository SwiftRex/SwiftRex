import SwiftRex

enum CounterAction: ActionProtocol {
    case increaseValue
    case decreaseValue
    case setLoading(Bool)
}
