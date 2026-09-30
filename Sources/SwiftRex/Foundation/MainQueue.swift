// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Runs `work` on the main actor: right away when the caller is already running on the main queue, after one hop
/// otherwise. Plumbing for bridges whose entry points aren't isolated (a Combine subscription, an RxSwift
/// `subscribe`), so the common case — subscribing from the main actor — delivers synchronously.
///
/// "Already there" means the main thread **or** a block of the main queue: on Linux `dispatch_main` retires the
/// main thread and a worker drains the main queue, so `Thread.isMainThread` alone is `false` there even on the
/// main actor.
package func onMainActor(_ work: @escaping @MainActor () -> Void) {
    if Thread.isMainThread || DispatchQueue.getSpecific(key: mainQueueKey) != nil {
        MainActor.assumeIsolated(work)
    } else {
        DispatchQueue.main.async { MainActor.assumeIsolated(work) }
    }
}

// Tags the main queue once, so `getSpecific` answers `true` exactly while the main queue is running a block.
private let mainQueueKey: DispatchSpecificKey<Void> = {
    let key = DispatchSpecificKey<Void>()
    DispatchQueue.main.setSpecific(key: key, value: ())
    return key
}()
