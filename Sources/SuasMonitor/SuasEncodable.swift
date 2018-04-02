//
//  SuasEncodable.swift
//  SuasIOS
//
//  Created by Omar Abdelhafith on 22/07/2017.
//  Copyright © 2017 Zendesk. All rights reserved.
//
import Foundation

#if swift(>=3.2)
/// Protocol used from `MonitorMiddleware` to convert a type to a dictionary `[String: Any]`
/// When using `MonitorMiddleware` types can implement `SuasEncodable` to be transferred to `SuasMonitor` mac app
///
/// **Note**: There is no need to implement `toDictionary` function manually since `SuasEncodable` uses Swift's `Encodable protocol behind the scene.
public protocol SuasEncodable: Encodable {

    /// Convert the type to a dictionary
    /// This method is implemented by default by using `JSONEncoder` from `Encodable`
    func toDictionary() -> [String: Any]
}

// MARK: - Extend Encodable to implement the required methods from `SuasEncodable`
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
#else
/// Protocol used from `MonitorMiddleware` to convert a type to a `[String: Any]`
/// When using `MonitorMiddleware` types can implement `SuasEncodable` to be transferred to Suas Monitor desktop app
public protocol SuasEncodable {

/// Convert the type to a dictionary to be transmitted to Suas Monitor desktop app
func toDictionary() -> [String: Any]
}
#endif
