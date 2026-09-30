// SPDX-License-Identifier: Apache-2.0

#if RxSwift
    import Foundation
    @preconcurrency import RxSwift
    import SwiftRex

    // MARK: - StateStream is an ObservableType

    /// A store's ``SwiftRex/StateStream`` **is** an RxSwift `ObservableType` — subscribe to it directly, or take
    /// `asObservable()`:
    ///
    /// ```swift
    /// store.stateStream
    ///     .asObservable()
    ///     .map(\.username)
    ///     .distinctUntilChanged()
    ///     .subscribe(onNext: { name in nameLabel.text = name })
    ///     .disposed(by: bag)
    /// ```
    ///
    /// The current value first, then every change; delivered on the main actor — synchronously when subscribing
    /// from the main thread, after one hop otherwise. Disposing removes the observer from the store.
    extension StateStream: ObservableType {
        nonisolated public func subscribe<Observer: ObserverType>(_ observer: Observer) -> any Disposable
        where Observer.Element == State {
            let subscription = RxStateSubscription<State>()
            // RxSwift observers aren't `Sendable`; this one is only ever called from the main actor, below.
            nonisolated(unsafe) let observer = observer
            onMain { [self] in
                subscription.token = observe { observer.onNext($0) }
            }
            return Disposables.create { onMain { subscription.token = nil } }
        }
    }

    // The token of one subscription; created and released only on the main actor.
    private final class RxStateSubscription<State>: @unchecked Sendable {
        @MainActor var token: UISubscriptionToken?
    }

    /// Runs `work` on the main actor: right away when already on the main thread, after one hop otherwise.
    private func onMain(_ work: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated(work)
        } else {
            DispatchQueue.main.async { MainActor.assumeIsolated(work) }
        }
    }
#endif
