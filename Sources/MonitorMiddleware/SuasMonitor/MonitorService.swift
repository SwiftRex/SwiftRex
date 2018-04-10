//
//  MonitorService.swift
//  Suas
//
//  Created by Omar Abdelhafith on 21/07/2017.
//  Copyright © 2017 Zendesk. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit.UIKitDefines
#endif

protocol MonitorService {
    func start(onConnectBlock: @escaping () -> Void)
    func send(data: Data)
}

class DefaultMonitorService: NSObject, MonitorService {

    let displayName: String

    var service: NetService?

    var streams: [(InputStream, OutputStream)] = []

    var onConnectBlock: (() -> Void)?

    init(displayName: String) {
        self.displayName = displayName
        super.init()

        #if os(iOS)
        NotificationCenter.default.addObserver(forName: .UIApplicationWillEnterForeground, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.connect()
        }
        #endif
    }

    func start(onConnectBlock: @escaping () -> Void) {
        self.onConnectBlock = onConnectBlock
        connect()
    }

    private func connect() {
        if self.service != nil {
            return
        }

        self.service = NetService(domain: "", type: "_suas-monitor._tcp.", name: displayName, port: 0)

        if let service = service {
            logString("Bonjour Service started")
            service.delegate = self
            service.publish(options: [.listenForConnections])
        }
    }

    func send(data: Data) {
        guard streams.count > 0 else { return }

        logString("Sending data to Suas monitor")

        for (_, stream) in streams {
            let bytesWritten = data.withUnsafeBytes {
                writeTo(stream: stream, data: $0, length: data.count)
            }

            if bytesWritten == -1 {
                if isStreamClosed(stream: stream) {
                    removeStream(stream: stream)
                    logString("Suas Monitor Disonnected To Client")
                } else {
                    logString("Error happened while sending data to Suas monitor")
                }
            }
        }
    }
}

// MARK: - Bonjour releated functions
extension DefaultMonitorService: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) { }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        self.service?.stop()
        self.service = nil
        logString("Failed publishing Bonjour Service")
    }

    func netService(_ sender: NetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream) {
        OperationQueue.main.addOperation {
            self.openAndAddStreams(inputStream: inputStream, outputStream: outputStream)
        }
    }

    func netServiceDidStop(_ sender: NetService) {
    }
}

// MARK: - Stream releated functions
extension DefaultMonitorService: StreamDelegate {
    func writeTo(stream: OutputStream, data: UnsafePointer<UInt8>, length: Int) -> Int {
        guard stream.hasSpaceAvailable else { return -1 }
        return stream.write(data, maxLength: length)
    }

    func openAndAddStreams(inputStream: InputStream, outputStream: OutputStream) {
        inputStream.delegate = self
        outputStream.delegate = self

        inputStream.schedule(in: RunLoop.main, forMode: .defaultRunLoopMode)
        outputStream.schedule(in: RunLoop.main, forMode: .defaultRunLoopMode)

        inputStream.open()
        outputStream.open()

        if streams.contains(where: { $0.0 === inputStream || $0.1 === outputStream }) { return }
        streams.append((inputStream, outputStream))
        logString("Suas Monitor Connected To Client. \(streams.count) monitors connected.")
    }

    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.openCompleted:
            if aStream is OutputStream {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: { self.onConnectBlock?() })
            }
            break

        case Stream.Event.errorOccurred:
            fallthrough
        case Stream.Event.endEncountered:
            removeStream(stream: aStream)
            break

        case Stream.Event.hasBytesAvailable:
            let data = Data(reading: (aStream as! InputStream))
            if data.count == 0 {
                removeStream(stream: aStream)
                logString("Suas Monitor Disonnected To Client")
            }
            break

        default:
            break
        }
    }

    func isStreamClosed(stream: Stream) -> Bool {
        if let error = stream.streamError, (error as NSError).code == 32 {
            return true
        } else {
            return false
        }
    }

    public func removeStream(stream: Stream) {
        streams = streams.filter { s in
            !(s.0 === stream || s.1 === stream)
        }
    }
}

func logError(_ params: @autoclosure () -> (type: String, callback: String, value: Any)) {
    #if DEBUG
    let (type, callback, value) = params()

    logString("`\(type)` can not be converted to [String: Any]\n" +
        "\(type): \(value)\n" +
        "-> State and Action can either implement the `SuasEncodable` or pass a callback to `\(callback)` when creating the `MonitorMiddleware`")
    #endif
}

func logString(_ string: @autoclosure () -> String) {
    #if DEBUG
    print("🖥 SuasMonitor: \(string())")
    #endif
}

extension Data {
    init(reading input: InputStream) {
        self.init()
        input.open()

        let bufferSize = 1_024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        while input.hasBytesAvailable {
            let read = input.read(buffer, maxLength: bufferSize)
            if read < 0 { break }

            self.append(buffer, count: read)
        }
        buffer.deallocate(capacity: bufferSize)

        input.close()
    }
}
