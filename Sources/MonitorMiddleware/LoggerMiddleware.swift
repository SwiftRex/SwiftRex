//
//  Adapted from LoggerMiddleware, Suas iOS (by Omar Abdelhafith on 22/07/2017)
//  Copyright © 2017 Zendesk. All rights reserved.
//

import SwiftRex

public final class LoggerMiddleware<GlobalState>: Middleware {
    public weak var actionHandler: ActionHandler?

    private let showDuration: Bool
    private let showTimestamp: Bool
    private let debugOnly: Bool
    private let lineLength: Int?
    private let logger: (String) -> Void
    private let eventFilter: (GlobalState, EventProtocol) -> Bool
    private let actionFilter: (GlobalState, ActionProtocol) -> Bool
    private let stateTransformer: (GlobalState) -> String
    private let eventTransformer: (EventProtocol) -> String
    private let actionTransformer: (ActionProtocol) -> String
    private let actionTitleFormatter: ((ActionProtocol, Date, UInt64) -> String)?
    private let eventTitleFormatter: ((EventProtocol, Date, UInt64) -> String)?
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    public init(
        showTimestamp: Bool = true,
        showDuration: Bool = false,
        lineLength: Int? = nil,
        eventFilter: @escaping (GlobalState, EventProtocol) -> Bool = { _, _ in true },
        actionFilter: @escaping (GlobalState, ActionProtocol) -> Bool = { _, _ in true },
        debugOnly: Bool = true,
        actionTitleFormatter: ((ActionProtocol, Date, UInt64) -> String)? = nil,
        eventTitleFormatter: ((EventProtocol, Date, UInt64) -> String)? = nil,
        stateTransformer: @escaping (GlobalState) -> String = { "\($0)" },
        actionTransformer: @escaping (ActionProtocol) -> String = { "\($0)" },
        eventTransformer: @escaping (EventProtocol) -> String = { "\($0)" },
        logger: @escaping (String) -> Void = defaultLogger) {

        self.showDuration = showDuration
        self.showTimestamp = showTimestamp
        self.eventFilter = eventFilter
        self.actionFilter = actionFilter
        self.debugOnly = debugOnly
        self.stateTransformer = stateTransformer
        self.actionTransformer = actionTransformer
        self.eventTransformer = eventTransformer
        self.actionTitleFormatter = actionTitleFormatter
        self.eventTitleFormatter = eventTitleFormatter
        self.lineLength = lineLength
        self.logger = logger
    }

    public func handle(event: EventProtocol, getState: @escaping GetState<GlobalState>, next: @escaping NextEventHandler<GlobalState>) {
        guard shouldLog, eventFilter(getState(), event) else {
            next(event, getState)
            return
        }

        let startTime = DispatchTime.now()

        next(event, getState)

        let endTime = DispatchTime.now()

        let firstLine = logEventTitle(event: event, startTime: startTime, endTime: endTime)

        logger([
            firstLine,
            line(prefix: "├─ Event      ► ", content: "\(eventTransformer(event))", length: lineLength),
            closingLine(length: firstLine.count)
            ].joined(separator: "\n"))
    }

    public func handle(action: ActionProtocol, getState: @escaping GetState<GlobalState>, next: @escaping NextActionHandler<GlobalState>) {
        guard shouldLog, actionFilter(getState(), action) else {
            next(action, getState)
            return
        }

        let oldState = getState()
        let startTime = DispatchTime.now()

        next(action, getState)

        let endTime = DispatchTime.now()
        let newState = getState()

        let firstLine = logActionTitle(action: action, startTime: startTime, endTime: endTime)
        logger([
            firstLine,
            line(prefix: "├─ Prev state ► ", content: "\(stateTransformer(oldState))", length: lineLength),
            line(prefix: "├─ Action     ► ", content: "\(actionTransformer(action))", length: lineLength),
            line(prefix: "├─ Next state ► ", content: "\(stateTransformer(newState))", length: lineLength),
            closingLine(length: firstLine.count)
        ].joined(separator: "\n"))
    }
}

extension LoggerMiddleware {
    private func logEventTitle(
        event: EventProtocol,
        startTime: DispatchTime,
        endTime: DispatchTime) -> String {
        let duration = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds

        if let titleFormatter = eventTitleFormatter {
            return titleFormatter(event, Date(), duration)
        } else {
            return title(
                type: "Event",
                value: "\(type(of: event))",
                duration: duration,
                date: Date(),
                showTimestamp: showTimestamp,
                showDuration: showDuration)
        }
    }

    private func logActionTitle(
        action: ActionProtocol,
        startTime: DispatchTime,
        endTime: DispatchTime) -> String {
        let duration = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds

        if let titleFormatter = actionTitleFormatter {
            return titleFormatter(action, Date(), duration)
        } else {
            return title(
                type: "Action",
                value: "\(type(of: action))",
                duration: duration,
                date: Date(),
                showTimestamp: showTimestamp,
                showDuration: showDuration)
        }
    }

    private func closingLine(length: Int) -> String {
        return "└" + String(repeating: "─", count: length - 1)
    }

    private var shouldLog: Bool {
        return !(isRelease && debugOnly)
    }

    private var isRelease: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
}

extension LoggerMiddleware {
    private func title(
        type: String,
        value: String,
        duration: UInt64,
        date: Date,
        showTimestamp: Bool,
        showDuration: Bool
        ) -> String {

        var parts = ["┌───→ \(type): \(value)"]

        if showTimestamp {
            parts.append("@\(timestamp(forDate: date))")
        }

        if showDuration && duration > 0 {
            parts.append("(in \(duration / 1_000) µs)")
        }

        return parts.joined(separator: " ")
    }

    private func line(prefix: String, content: String, length: Int?) -> String {
        guard let lenght = length else { return prefix + content }

        let prefixLength = prefix.count
        let lineLength = lenght - prefixLength - 1
        var restOfString = content
        var parts: [String] = []

        let firstPrefix = prefix
        let linesPrefix = "│" + String(repeatElement(" ", count: prefixLength - 1))

        while true {
            let prefixPart = parts.count == 0 ? firstPrefix : linesPrefix

            if restOfString.count < lineLength {
                parts.append(prefixPart + restOfString)
                break
            } else {
                let index = restOfString.index(restOfString.startIndex, offsetBy: lineLength)
                let stringPart = String(restOfString[..<index])
                restOfString = String(restOfString[index...])

                parts.append(prefixPart + stringPart)
            }
        }

        return parts.joined(separator: "\n")
    }

    private func timestamp(forDate date: Date) -> String {
        return dateFormatter.string(from: date)
    }
}

public let defaultLogger = { (string: String) in
    print(string)
}
