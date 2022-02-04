import SwiftRex

extension StoreType where StateType: Equatable {
  public func asViewStore(
    initialState: StateType
  ) -> ViewStore<ActionType, StateType> {
    .init(initialState: initialState, store: self, emitsValue: .whenDifferent)
  }
}
