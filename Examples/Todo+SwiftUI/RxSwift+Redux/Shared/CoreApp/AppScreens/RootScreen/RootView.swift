import SwiftUI
import SwiftRex
import RxSwiftRex

struct RootView: View {
  
  private let store: ReduxStoreBase<RootAction, RootState>
  
  @ObservedObject
  private var viewStore: ViewStore<RootAction, RootState>
  
  init(store: ReduxStoreBase<RootAction, RootState>? = nil) {
    let unwrapStore = store ?? ReduxStoreBase(
      subject: .rx(initialValue: RootState()),
      reducer: rootReducer,
      middleware: rootMiddleware
    )
    self.store = unwrapStore
    self.viewStore = unwrapStore.asViewStore(initialState: RootState())
  }
  
  var body: some View {
    ZStack {
      switch viewStore.state.rootScreen {
      case .main:
        MainView(store: store.projection(action: RootAction.mainAction, state: {$0.mainState}))
      case .auth:
        AuthView(store: store.projection(action: RootAction.authAction, state: {$0.authState}))
      }
    }
    .onAppear {
      viewStore.send(.viewOnAppear)
    }
    .onDisappear {
      viewStore.send(.viewOnDisappear)
    }
#if os(macOS)
    .frame(minWidth: 700, idealWidth: 700, maxWidth: .infinity, minHeight: 500, idealHeight: 500, maxHeight: .infinity, alignment: .center)
#endif
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
