/**
 * Copyright 2024-2025 Wingify Software Pvt. Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

class LoggerService {
    
    // Thread-safe static message dictionaries
    private static let messageLock = NSLock()
    private static var _debugMessages: [String: String] = [:]
    private static var _errorMessages: [String: String] = [:]
    private static var _infoMessages: [String: String] = [:]
    private static var _warningMessages: [String: String] = [:]
    private static var _traceMessages: [String: String] = [:]
    
    static var debugMessages: [String: String] {
        get {
            messageLock.lock()
            defer { messageLock.unlock() }
            return _debugMessages
        }
        set {
            messageLock.lock()
            defer { messageLock.unlock() }
            _debugMessages = newValue
        }
    }
    
    static var errorMessages: [String: String] {
        get {
            messageLock.lock()
            defer { messageLock.unlock() }
            return _errorMessages
        }
        set {
            messageLock.lock()
            defer { messageLock.unlock() }
            _errorMessages = newValue
        }
    }
    
    static var infoMessages: [String: String] {
        get {
            messageLock.lock()
            defer { messageLock.unlock() }
            return _infoMessages
        }
        set {
            messageLock.lock()
            defer { messageLock.unlock() }
            _infoMessages = newValue
        }
    }
    
    static var warningMessages: [String: String] {
        get {
            messageLock.lock()
            defer { messageLock.unlock() }
            return _warningMessages
        }
        set {
            messageLock.lock()
            defer { messageLock.unlock() }
            _warningMessages = newValue
        }
    }
    
    static var traceMessages: [String: String] {
        get {
            messageLock.lock()
            defer { messageLock.unlock() }
            return _traceMessages
        }
        set {
            messageLock.lock()
            defer { messageLock.unlock() }
            _traceMessages = newValue
        }
    }
    
    init(config: [String: Any], logLevel: LogLevelEnum, logTransport: LogTransport?) {
        // Initialize the LogManager using thread-safe method
        _ = LogManager.createInstance(config: config, logLevel: logLevel, logTransport: logTransport)
        
        // Read the log files (only once) - thread-safe
        LoggerService.messageLock.lock()
        defer { LoggerService.messageLock.unlock() }
        
        if LoggerService._debugMessages.isEmpty {
            LoggerService._debugMessages = readLogFiles(fileName: "debug-messages.json")
            LoggerService._infoMessages = readLogFiles(fileName: "info-messages.json")
            LoggerService._errorMessages = readLogFiles(fileName: "error-messages.json")
            LoggerService._warningMessages = readLogFiles(fileName: "warn-messages.json")
            LoggerService._traceMessages = readLogFiles(fileName: "trace-messages.json")
        }
    }
    
    /**
     * Thread-safe method to create LoggerService instance
     */
    static func createInstance(config: [String: Any], logLevel: LogLevelEnum, logTransport: LogTransport?) -> LoggerService {
        return LoggerService(config: config, logLevel: logLevel, logTransport: logTransport)
    }
    
    /**
     * Reads the log files and returns the messages in a dictionary.
     */
    private func readLogFiles(fileName: String) -> [String: String] {
        do {
#if SWIFT_PACKAGE
            // For Swift Package Manager
            let bundle = Bundle.module
#else
            // For CocoaPods
            let bundle = Bundle(for: type(of: self))
#endif
            
            // Attempt to find the file with or without an extension
            if let url = bundle.url(forResource: fileName, withExtension: nil) ?? bundle.url(forResource: fileName, withExtension: "json") {
                let data = try Data(contentsOf: url)
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    return json as? [String: String] ?? [:]
                }
            }
        } catch {
            LoggerService.log(level: .error, message: "Error reading log files: \(error.localizedDescription)")
        }
        return [:]
    }
    
    static func getLogFile(level: LogLevelEnum) -> [String: String] {
        switch level {
        case .trace:
            return LoggerService.traceMessages
        case .debug:
            return LoggerService.debugMessages
        case .info:
            return LoggerService.infoMessages
        case .warn:
            return LoggerService.warningMessages
        case .error:
            return LoggerService.errorMessages
        }
    }
    
    static func log(level: LogLevelEnum, key: String, details: [String: String]?) {
        let logFile = self.getLogFile(level: level)
        let messageBuilder = LogMessageUtil.buildMessage(template: logFile[key], data: details)
        guard let logManager = LogManager.instance else { return }
        logManager.log(level: level, message: messageBuilder)
    }
    
    static func errorLog(key: String, data: [String: Any]? = nil, debugData: [String: Any]? = nil,shouldSendToVWO: Bool  = true) {
        guard let logManager = LogManager.instance else { return }
        logManager.errorLog(key: key, data: data, debugData: debugData, shouldSendToVWO: shouldSendToVWO)
    }
    
    static func log(level: LogLevelEnum, message: String?) {
        guard let logManager = LogManager.instance else { return }
        logManager.log(level: level, message: message)
    }
}
