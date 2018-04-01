import SwiftRex

enum CounterAction: Action {
    case increaseValue
    case decreaseValue
    case setLoading(Bool)
}
