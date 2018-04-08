import Foundation

public extension Encodable {
    public func toDictionary() -> [String: Any] {
        guard
            let data = try? JSONEncoder().encode(self),
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            else {
                logString("Type \(type(of: self)) was not encodable to JSON")
                return [:]
        }

        return json
    }
}
