import Foundation

enum CounterAction: Equatable {
  case viewDidLoad
  case viewWillAppear
  case viewWillDisappear
  case none
  case increment
  case decrement
}
