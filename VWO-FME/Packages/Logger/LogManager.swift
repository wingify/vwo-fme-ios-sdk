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
    // Concurrent queue for thread-safe access to sentMessages (better performance than locks)
    // Reads can happen concurrently, writes are serialized with barriers
    private let sentMessagesQueue = DispatchQueue(label: "com.vwo.fme.logmanager.sentMessages", attributes: .concurrent)

    
    // Thread-safe singleton implementation
    private static var _instance: LogManager?
    private static let instanceQueue = DispatchQueue(label: "com.vwo.fme.logmanager.instance", attributes: .concurrent)
    
    static var instance: LogManager? {
        get {
            return instanceQueue.sync {
                return _instance
            }
        }
        set {
            instanceQueue.async(flags: .barrier) {
                _instance = newValue
            }
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
    ///   This method uses double-checked locking pattern with concurrent queue to optimize performance.
    static func createInstance(config: [String: Any], logLevel: LogLevelEnum, logTransport: LogTransport?) -> LogManager {
        // Quick check without barrier first (concurrent read)
        if let existing = instanceQueue.sync(execute: { _instance }) {
            return existing
        }
        
        // Use barrier to ensure only one thread creates the instance
        return instanceQueue.sync(flags: .barrier) {
            // Check again after acquiring barrier
            if let existing = _instance {
                return existing
            }
            
            // Create and store the instance
            _instance = LogManager(config: config, logLevel: logLevel, logTransport: logTransport)
            return _instance!
        }
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
     *   - serviceContainer: Optional ServiceContainer to use for error event sending (for multi-instance support).
     */
    private func logMessage(level: LogLevelEnum, message: String?, serviceContainer: ServiceContainer?) {
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
        
        // Format the message: Since LogManager is a singleton and prefix is always empty (set by LoggerService),
        // we always use the tag. The message may already contain an instance prefix from LoggerService.
        let messageText = message ?? ""
        let formatMessage = "\(tag): \(level.levelIndicator): \(messageText)"
        
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
            self.logMessage(level: level, message: message, serviceContainer: nil)
        }
    }
    
    /**
     * Logs a message if the specified log level is enabled.
     * This overload accepts a ServiceContainer to ensure error events are sent with the correct account context.
     *
     * - Parameters:
     *   - level: The log level for the message.
     *   - message: The message to be logged.
     *   - serviceContainer: Optional ServiceContainer to use for error event sending (for multi-instance support).
     *   - skipLevelCheck: If true, skips the log level check (for use when level is already checked in LoggerService).
     */
    func log(level: LogLevelEnum, message: String?, serviceContainer: ServiceContainer?, skipLevelCheck: Bool = false) {
        guard let message = message else { return }
        
        // Only check level if not already checked in LoggerService
        if !skipLevelCheck {
            let configLevel = self.level
            let requiredLevel = level
            let shouldLogMessage = configLevel.level <= requiredLevel.level
            guard shouldLogMessage else { return }
        }
        
        self.logMessage(level: level, message: message, serviceContainer: serviceContainer)
    }
    
    /**
     * Sends a message event if the message has not been sent before.
     *
     * This method checks if the provided message is non-nil, non-empty, and has not
     * been previously sent. If all conditions are met, it sends the message event
     * and records the message to prevent future duplicate sends.
     *
     * Uses a concurrent queue with barriers for thread-safe access, allowing concurrent reads
     * while serializing writes. This provides better performance than locks and prevents
     * blocking during initialization of multiple instances.
     *
     * - Parameters:
     *   - message: The message to be sent as an event. If the message is
     *     nil or empty, the method does nothing.
     *   - serviceContainer: Optional ServiceContainer to use for error event sending (for multi-instance support).
     */
    private func sendMessageEventIfNeeded(message: String?, serviceContainer: ServiceContainer?) {
        guard let message = message, !message.isEmpty else { return }
        
        // Use concurrent queue with barrier for thread-safe access
        // Concurrent reads are allowed, but writes are serialized with barriers
        // This provides better performance than locks and doesn't block other operations
        var shouldSendEvent = false
        
        // Atomic check-and-insert using barrier to ensure thread safety
        sentMessagesQueue.sync(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if !self.sentMessages.contains(message) {
                self.sentMessages.insert(message)
                shouldSendEvent = true
            }
        }
        
        // Send event outside the queue to avoid blocking
        if shouldSendEvent {
            LogMessageUtil.sendMessageEvent(message: message, serviceContainer: serviceContainer)
        }
    }
    
     func errorLog(key: String, data: [String: Any]? = nil, debugData: [String: Any]? = nil, shouldSendToVWO: Bool, serviceContainer: ServiceContainer? = nil) {
        // Lookup message template from errorMessages dictionary
         let template = LoggerService.getLogFile(level: .error)
        
        // Format the message using the template and data
        let message = LogMessageUtil.buildMessage(template: template[key], data: data) ?? "Unknown error"
       
         self.log(level: .error, message: message, serviceContainer: serviceContainer)
         
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

            DebuggerServiceUtil.sendDebugEventToVWO(eventProps: debugEventProps, serviceContainer: serviceContainer)
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
