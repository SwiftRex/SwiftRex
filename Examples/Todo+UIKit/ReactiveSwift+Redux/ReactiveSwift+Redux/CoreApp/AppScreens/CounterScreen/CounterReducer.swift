import Foundation
import SwiftRex

let CounterReducer = Reducer<CounterAction, CounterState>.reduce { action, state in
  switch action {
  case .increment:
    state.count += 1
  case .decrement:
    state.count -= 1
  default:
    break
  }
}
