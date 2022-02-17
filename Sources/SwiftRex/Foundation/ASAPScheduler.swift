#if canImport(Combine)
import Combine
import Foundation

/// A very eager scheduler that will perform tasks in the Main Queue, immediately if possible.
///
/// If current queue is MainQueue, it will behave like ``ImmediateScheduler`` (https://developer.apple.com/documentation/combine/immediatescheduler)
/// and perform the task immediately in the current RunLoop. If the queue is different, then it will schedule to the Main Dispatch Queue and perform
/// as soon as its new RunLoop starts (depending on the DispatchQueue.SchedulerOptions provided).
/// Use ``ASAPScheduler.default`` in order to use this Scheduler.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct ASAPScheduler {
    public static let `default` = ASAPScheduler()

    private init() {
        DispatchQueue.setMainQueueID()
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension ASAPScheduler: Scheduler {
    public var now: DispatchQueue.SchedulerTimeType { DispatchQueue.main.now }

    public var minimumTolerance: DispatchQueue.SchedulerTimeType.Stride { DispatchQueue.main.minimumTolerance }

    public func schedule(options: DispatchQueue.SchedulerOptions? = nil, _ action: @escaping () -> Void) {
        DispatchQueue.asap(options: options, action)
    }

    public func schedule(
        after date: DispatchQueue.SchedulerTimeType,
        tolerance: DispatchQueue.SchedulerTimeType.Stride,
        options: DispatchQueue.SchedulerOptions? = nil,
        _ action: @escaping () -> Void
    ) {
        DispatchQueue.main.schedule(after: date, tolerance: tolerance, options: options, action)
    }

    public func schedule(
        after date: DispatchQueue.SchedulerTimeType,
        interval: DispatchQueue.SchedulerTimeType.Stride,
        tolerance: DispatchQueue.SchedulerTimeType.Stride,
        options: DispatchQueue.SchedulerOptions? = nil,
        _ action: @escaping () -> Void
    ) -> Cancellable {
        DispatchQueue.main.schedule(
            after: date, interval: interval, tolerance: tolerance, options: options, action
        )
    }
}
#endif
