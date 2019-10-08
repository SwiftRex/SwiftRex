import Foundation

public struct ViewStore<ViewAction, ViewState>: StoreType {
    public var statePublisher: UnfailablePublisherType<ViewState>
    private var onAction: (ViewAction) -> Void

    init(action: @escaping (ViewAction) -> Void, state: UnfailablePublisherType<ViewState>) {
        self.onAction = action
        self.statePublisher = state
    }

    public func dispatch(_ action: ViewAction) {
        onAction(action)
    }
}

extension StoreType {
    public func view<ViewAction, ViewState>(
        action viewActionToGlobalAction: @escaping (ViewAction) -> ActionType?,
        state globalStateToViewState: @escaping (UnfailablePublisherType<StateType>) -> UnfailablePublisherType<ViewState>)
        -> ViewStore<ViewAction, ViewState> {
        .init(
            action: { viewAction in
                guard let globalAction = viewActionToGlobalAction(viewAction) else { return }
                self.dispatch(globalAction)
            },
            state: globalStateToViewState(statePublisher)
        )
    }
}
