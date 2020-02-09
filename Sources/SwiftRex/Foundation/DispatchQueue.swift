import Foundation

extension DispatchQueue {
    private static let dispatchSpecificKey = DispatchSpecificKey<UUID>()
    private static let dispatchSpecificValue = UUID()

    static var isMainQueue: Bool {
        guard let queueUUID = DispatchQueue.getSpecific(key: DispatchQueue.dispatchSpecificKey),
            queueUUID == DispatchQueue.dispatchSpecificValue,
            Thread.isMainThread else { return false }

        return true
    }

    static func setMainQueueID() {
        DispatchQueue.main.setSpecific(key: DispatchQueue.dispatchSpecificKey, value: DispatchQueue.dispatchSpecificValue)
    }

    static func asap(_ block: @escaping () -> Void) {
        if DispatchQueue.isMainQueue {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
}
