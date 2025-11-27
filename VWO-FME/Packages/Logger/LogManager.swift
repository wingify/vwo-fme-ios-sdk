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
import os
/**
 * Interface for managing log operations.
 *
 * This interface defines methods for configuring and interacting with log transports,
 * as well as for retrieving log-related information such as the current log level,
 * prefix, and date-time format.
 */

internal class LogManager {

    
    let dateTimeForm: DateFormatter
    var level: LogLevelEnum
    private var tag = "VWO FME Logger"
    private var prefix: String = ""
    private let logTransport: LogTransport?
    private var sentMessages: Set<String> = []

    
    // Thread-safe singleton implementation
    private static var _instance: LogManager?
    private static let lock = NSLock()
    
    static var instance: LogManager? {
        get {
            return _instance
        }
        set {
            _instance = newValue
        }
    }
    
    /// Creates or returns the existing singleton instance of `LogManager`.
    ///
    /// This is a **thread-safe** method used to initialize or retrieve a shared instance of the `LogManager`
    /// responsible for handling SDK logging. It ensures that only one instance is created throughout
    /// the application's lifecycle, even in multi-threaded environments.
    ///
    /// - Parameters:
    ///   - config: A dictionary containing configuration settings required for logger initialization.
    ///   - logLevel: The logging level to be used (e.g., `.debug`, `.info`, `.error`).
    ///   - logTransport: An optional transport handler for sending logs to external systems (e.g., file, network).
    ///
    /// - Returns: A shared `LogManager` instance configured with the provided settings.
    ///
    /// - Note:
    ///   This method uses double-checked locking to optimize performance by avoiding unnecessary locking
    ///   after the instance has been initialized.
    static func createInstance(config: [String: Any], logLevel: LogLevelEnum, logTransport: LogTransport?) -> LogManager {
        // Quick check without lock first
        if let existing = _instance {
            return existing
        }
        
        // Only lock when we need to create
        lock.lock()
        defer { lock.unlock() }
        
        // Check again after acquiring lock
        if let existing = _instance {
            return existing
        }
        
        // Create and store the instance
        _instance = LogManager(config: config, logLevel: logLevel, logTransport: logTransport)
        return _instance!
    }
    
    /**
     * Initializes a new instance of LogManager.
     *
     * - Parameters:
     *   - config: A dictionary containing configuration settings.
     *   - logLevel: The initial log level.
     */
    init(config: [String: Any], logLevel: LogLevelEnum, logTransport: LogTransport?) {
        self.level = logLevel
        self.dateTimeForm = DateFormatter()
        self.dateTimeForm.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        self.prefix = config["prefix"] as! String
        self.logTransport = logTransport
        LogManager.instance = self
    }
    
    /**
     * Retrieves the current date and time as a formatted string.
     *
     * - Returns: A string representing the current date and time.
     */
    private func getDateAndTime() -> String {
        let now = Date()
        let dateString = self.dateTimeForm.string(from: now)
        return dateString
    }
    
    /**
     * Logs a message with a specified log level.
     *
     * - Parameters:
     *   - level: The log level for the message.
     *   - message: The message to be logged.
     */
    private func logMessage(level: LogLevelEnum, message: String?) {
        var osLogType: OSLogType = .default
        switch level {
        case .trace, .debug:
            osLogType = .debug
        case .info:
            osLogType = .info
        case .warn:
            osLogType = .default
        case .error:
            osLogType = .error
        }
        let formatMessage = "\(prefix.isEmpty ? "\(tag)" : "\(prefix)"): \(level.levelIndicator): \(message ?? "")"
        
        if let logTransport = self.logTransport {
            logTransport.log(logType: level.rawValue, message: formatMessage)
        } else {
            os_log("%{public}@", log: OSLog(subsystem: tag, category: level.rawValue), type: osLogType, formatMessage)
        }
    }
    
    /**
     * Logs a message if the specified log level is enabled.
     *
     * - Parameters:
     *   - level: The log level for the message.
     *   - message: The message to be logged.
     */
    func log(level: LogLevelEnum, message: String?) {
        guard let message = message else { return }
        let configLevel = self.level
        let requiredLevel = level
        let shouldLogMessage = configLevel.level <= requiredLevel.level
        if shouldLogMessage {
            self.logMessage(level: level, message: message)
        }
    }
    
    /**
     * Sends a message event if the message has not been sent before.
     *
     * This method checks if the provided message is non-nil, non-empty, and has not
     * been previously sent. If all conditions are met, it sends the message event
     * and records the message to prevent future duplicate sends.
     *
     * - Parameter message: The message to be sent as an event. If the message is
     *   nil or empty, the method does nothing.
     */
    private func sendMessageEventIfNeeded(message: String?) {
        if let message = message, !message.isEmpty, !sentMessages.contains(message) {
            sentMessages.insert(message)
            LogMessageUtil.sendMessageEvent(message: message)
        }
    }
    
     func errorLog(key: String, data: [String: Any]? = nil, debugData: [String: Any]? = nil,shouldSendToVWO: Bool ) {
        // Lookup message template from errorMessages dictionary
         let template = LoggerService.getLogFile(level: .error)
        
        // Format the message using the template and data
        let message = LogMessageUtil.buildMessage(template: template[key], data: data) ?? "Unknown error"
       
         self.log(level: .error, message: message)
         
        // Conditionally send to VWO
        if shouldSendToVWO {
            var debugEventProps: [String: Any] = [:]

            if let debugData = debugData {
                debugEventProps.merge(debugData) { _, new in new }
            }

            if let data = data {
                debugEventProps.merge(data) { _, new in new }
            }

            debugEventProps["msg_t"] = key
            debugEventProps["lt"] = LogLevelEnum.error.rawValue
            debugEventProps["cg"] = DebuggerCategoryEnum.ERROR.rawValue
            debugEventProps["msg"] = message

            DebuggerServiceUtil.sendDebugEventToVWO(eventProps: debugEventProps)
        }
    }
}

/**
 * The `LogTransport` protocol defines a standardized interface for handling log messages within the SDK.
 * It serves as a bridge for capturing and redirecting log messages from the native SDK to external systems,
 * In the context of a React Native bridge, the `log` method can be used to emit events to JavaScript,
 * enabling the display of native log messages in the JavaScript console.
 */
public protocol LogTransport {
    func log(logType: String, message: String)
}
