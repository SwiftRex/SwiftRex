import SwiftUI
import RxSwiftRex
import SwiftRex
import ConvertSwift

struct CounterView: View {
  
  private let store: AnyStoreType<CounterAction, CounterState>
  
  @ObservedObject
  private var viewStore: ViewStore<CounterAction, CounterState>
  
  init(store: AnyStoreType<CounterAction, CounterState>? = nil) {
    let unwrapStore = store ?? ReduxStoreBase(
      subject: .rx(initialValue: CounterState()),
      reducer: CounterReducer,
      middleware: IdentityMiddleware<CounterAction, CounterAction, CounterState>()
    )
      .eraseToAnyStoreType()
    self.store = unwrapStore
    self.viewStore = unwrapStore.asViewStore(initialState: CounterState())
  }
  
  var body: some View {
    ZStack {
      HStack {
        Button {
          viewStore.send(.increment)
        } label: {
          Text("+")
        }
        Text(viewStore.count.toString())
        Button {
          viewStore.send(.decrement)
        } label: {
          Text("-")
        }
      }
    }
    .onAppear {
      viewStore.send(.viewOnAppear)
    }
    .onDisappear {
      viewStore.send(.viewOnDisappear)
    }
  }
}

struct CounterView_Previews: PreviewProvider {
  static var previews: some View {
    CounterView()
  }
}
