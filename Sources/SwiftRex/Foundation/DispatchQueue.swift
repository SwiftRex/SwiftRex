import Foundation

extension DispatchQueue {
    private static let dispatchSpecificKey = DispatchSpecificKey<UUID>()
    private static let dispatchSpecificValue = UUID()

    public static var isMainQueue: Bool {
        guard let queueUUID = DispatchQueue.getSpecific(key: DispatchQueue.dispatchSpecificKey),
            queueUUID == DispatchQueue.dispatchSpecificValue,
            Thread.isMainThread else { return false }

        return true
    }

    static func setMainQueueID() {
        DispatchQueue.main.setSpecific(key: DispatchQueue.dispatchSpecificKey, value: DispatchQueue.dispatchSpecificValue)
    }

    public static func asap(_ block: @escaping () -> Void) {
        if DispatchQueue.isMainQueue {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public static func asap(options: DispatchQueue.SchedulerOptions?, _ block: @escaping () -> Void) {
        if DispatchQueue.isMainQueue {
            block()
        } else {
            DispatchQueue.main.schedule(options: options) {
                block()
            }
        }
    }
}
