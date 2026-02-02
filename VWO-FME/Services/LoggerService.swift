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
    
    // Instance-specific prefix for multi-instance support
    // Made internal so static methods can access it for prefix lookup
    internal let instancePrefix: String
    
    // Instance-specific log level for multi-instance support
    private let instanceLogLevel: LogLevelEnum
    
    // Thread-safe storage for LoggerService instances by account key (for static log prefix lookup)
    private static let instanceQueue = DispatchQueue(label: "com.vwo.fme.loggerservice.instances", attributes: .concurrent)
    private static var _instances: [String: LoggerService] = [:]
    
    // Thread-safe static message dictionaries
    private static let messageQueue = DispatchQueue(label: "com.vwo.fme.loggerservice.messages", attributes: .concurrent)
    private static var _debugMessages: [String: String] = [:]
    private static var _errorMessages: [String: String] = [:]
    private static var _infoMessages: [String: String] = [:]
    private static var _warningMessages: [String: String] = [:]
    private static var _traceMessages: [String: String] = [:]
    
    static var debugMessages: [String: String] {
        get {
            return messageQueue.sync {
                return _debugMessages
            }
        }
        set {
            messageQueue.async(flags: .barrier) {
                _debugMessages = newValue
            }
        }
    }
    
    static var errorMessages: [String: String] {
        get {
            return messageQueue.sync {
                return _errorMessages
            }
        }
        set {
            messageQueue.async(flags: .barrier) {
                _errorMessages = newValue
            }
        }
    }
    
    static var infoMessages: [String: String] {
        get {
            return messageQueue.sync {
                return _infoMessages
            }
        }
        set {
            messageQueue.async(flags: .barrier) {
                _infoMessages = newValue
            }
        }
    }
    
    static var warningMessages: [String: String] {
        get {
            return messageQueue.sync {
                return _warningMessages
            }
        }
        set {
            messageQueue.async(flags: .barrier) {
                _warningMessages = newValue
            }
        }
    }
    
    static var traceMessages: [String: String] {
        get {
            return messageQueue.sync {
                return _traceMessages
            }
        }
        set {
            messageQueue.async(flags: .barrier) {
                _traceMessages = newValue
            }
        }
    }
    
    init(config: [String: Any], logLevel: LogLevelEnum, logTransport: LogTransport?, accountId: Int? = nil, sdkKey: String? = nil) {
        // Store instance-specific log level
        self.instanceLogLevel = logLevel
        
        // Initialize or reuse the shared LogManager instance with NO prefix
        var sharedConfig = config
        sharedConfig["prefix"] = ""
        _ = LogManager.createInstance(config: sharedConfig, logLevel: logLevel, logTransport: logTransport)
        
        // Capture instance-specific prefix (do NOT rely on shared LogManager prefix)
        if let prefix = config["prefix"] as? String {
            self.instancePrefix = prefix
        } else {
            self.instancePrefix = ""
        }
        
        // Register this instance for static log prefix lookup
        // Use provided accountId/sdkKey first, then fallback to SettingsManager
        let accountKey: String?
        if let accountId = accountId, let sdkKey = sdkKey {
            accountKey = "\(accountId)_\(sdkKey)"
        } else if let settingsManager = SettingsManager.instance {
            accountKey = "\(settingsManager.accountId)_\(settingsManager.sdkKey)"
        } else {
            accountKey = nil
        }
        
        if let accountKey = accountKey {
            LoggerService.instanceQueue.async(flags: .barrier) {
                LoggerService._instances[accountKey] = self
            }
        }
        
        // Read the log files (only once) - thread-safe
        LoggerService.messageQueue.sync(flags: .barrier) {
            if LoggerService._debugMessages.isEmpty {
                LoggerService._debugMessages = readLogFiles(fileName: "debug-messages.json")
                LoggerService._infoMessages = readLogFiles(fileName: "info-messages.json")
                LoggerService._errorMessages = readLogFiles(fileName: "error-messages.json")
                LoggerService._warningMessages = readLogFiles(fileName: "warn-messages.json")
                LoggerService._traceMessages = readLogFiles(fileName: "trace-messages.json")
            }
        }
    }
    
    /**
     * Thread-safe method to create LoggerService instance
     */
    static func createInstance(config: [String: Any], logLevel: LogLevelEnum, logTransport: LogTransport?, accountId: Int? = nil, sdkKey: String? = nil) -> LoggerService {
        return LoggerService(config: config, logLevel: logLevel, logTransport: logTransport, accountId: accountId, sdkKey: sdkKey)
    }
    
    /**
     * Registers a LoggerService instance with an account key for static log prefix lookup.
     * This can be called multiple times to update the registration.
     */
    static func registerInstance(accountKey: String, instance: LoggerService) {
        instanceQueue.async(flags: .barrier) {
            _instances[accountKey] = instance
        }
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
    
    /**
     * Gets the prefix from the appropriate LoggerService instance for static logging.
     * This allows static logs to use the correct instance prefix based on current SettingsManager.
     */
    private static func getCurrentInstancePrefix() -> String {
        return instanceQueue.sync {
            // First, try to get the instance using SettingsManager.instance
            if let settingsManager = SettingsManager.instance {
                let accountKey = "\(settingsManager.accountId)_\(settingsManager.sdkKey)"
                if let instance = _instances[accountKey], !instance.instancePrefix.isEmpty {
                    return instance.instancePrefix
                }
            }
            
            // Fallback: if we have only one instance with a non-empty prefix, use it
            // This handles cases where SettingsManager.instance might not be set correctly
            let instancesWithPrefix = _instances.values.filter { !$0.instancePrefix.isEmpty }
            if instancesWithPrefix.count == 1 {
                return instancesWithPrefix.first!.instancePrefix
            }
            
            // If multiple instances exist, try to find the one that matches SettingsManager
            // by checking all registered instances
            if let settingsManager = SettingsManager.instance {
                for (accountKey, instance) in _instances {
                    let expectedKey = "\(settingsManager.accountId)_\(settingsManager.sdkKey)"
                    if accountKey == expectedKey && !instance.instancePrefix.isEmpty {
                        return instance.instancePrefix
                    }
                }
            }
            
            return ""
        }
    }
    
    /**
     * Gets a LoggerService instance by account key for batch processing logs.
     * - Parameters:
     *   - accountId: The account ID
     *   - sdkKey: The SDK key
     * - Returns: The LoggerService instance if found, nil otherwise
     */
    static func getInstance(accountId: Int, sdkKey: String) -> LoggerService? {
        let accountKey = "\(accountId)_\(sdkKey)"
        return instanceQueue.sync {
            return _instances[accountKey]
        }
    }
    
    static func log(level: LogLevelEnum, key: String, details: [String: String]?) {
        let logFile = self.getLogFile(level: level)
        let messageBuilder = LogMessageUtil.buildMessage(template: logFile[key], data: details)
        
        // Try to get the current instance prefix to prepend
        let prefix = getCurrentInstancePrefix()
        let finalMessage = prefix.isEmpty ? messageBuilder : "\(prefix): \(messageBuilder ?? "")"
        
        guard let logManager = LogManager.instance else { return }
        logManager.log(level: level, message: finalMessage)
    }
    
     func errorLog(key: String, data: [String: Any]? = nil, debugData: [String: Any]? = nil, shouldSendToVWO: Bool = true) {
        // Get ServiceContainer from this LoggerService instance (set during ServiceContainer initialization)
        // This ensures error logs are sent to the correct account in multi-instance scenarios
        let serviceContainer = self.serviceContainer
        
        // Build the message with instance prefix (similar to log() method)
        let template = LoggerService.getLogFile(level: .error)
        let message = LogMessageUtil.buildMessage(template: template[key], data: data) ?? "Unknown error"
        let finalMessage = instancePrefix.isEmpty ? message : "\(instancePrefix): \(message)"
        
        // Log the message with prefix
        LogManager.instance?.log(level: .error, message: finalMessage, serviceContainer: serviceContainer, skipLevelCheck: true)
        
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
            debugEventProps["msg"] = message  // Use original message without prefix for VWO
            
            DebuggerServiceUtil.sendDebugEventToVWO(eventProps: debugEventProps, serviceContainer: serviceContainer)
        }
    }
    
    static func log(level: LogLevelEnum, message: String?) {
        // Try to get the current instance prefix to prepend
        let prefix = getCurrentInstancePrefix()
        let finalMessage = prefix.isEmpty ? message : "\(prefix): \(message ?? "")"
        
        guard let logManager = LogManager.instance else { return }
        logManager.log(level: level, message: finalMessage)
    }
    
    /**
     * Static method for errorLog that retrieves the appropriate LoggerService instance
     * based on the current SettingsManager.instance and calls the instance method.
     * This allows static calls like LoggerService.errorLog(...) to work correctly.
     */
    static func errorLog(key: String, data: [String: Any]? = nil, debugData: [String: Any]? = nil, shouldSendToVWO: Bool = true) {
        // Try to get the appropriate LoggerService instance
        if let instance = getInstanceForStaticCall() {
            // Use the instance method which has access to ServiceContainer
            instance.errorLog(key: key, data: data, debugData: debugData, shouldSendToVWO: shouldSendToVWO)
        } else {
            // Fallback: build message with prefix if available, then use LogManager directly
            let template = LoggerService.getLogFile(level: .error)
            let message = LogMessageUtil.buildMessage(template: template[key], data: data) ?? "Unknown error"
            let prefix = getCurrentInstancePrefix()
            let finalMessage = prefix.isEmpty ? message : "\(prefix): \(message)"
            
            // Log with prefix
            LogManager.instance?.log(level: .error, message: finalMessage, serviceContainer: nil, skipLevelCheck: true)
            
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
                
                DebuggerServiceUtil.sendDebugEventToVWO(eventProps: debugEventProps, serviceContainer: nil)
            }
        }
    }
    
    /**
     * Gets the appropriate LoggerService instance for static method calls.
     * Uses SettingsManager.instance to determine which instance to use.
     */
    private static func getInstanceForStaticCall() -> LoggerService? {
        return instanceQueue.sync {
            // First, try to get the instance using SettingsManager.instance
            if let settingsManager = SettingsManager.instance {
                let accountKey = "\(settingsManager.accountId)_\(settingsManager.sdkKey)"
                if let instance = _instances[accountKey] {
                    return instance
                }
            }
            
            // Fallback: if we have only one instance, use it
            if _instances.count == 1 {
                return _instances.values.first
            }
            
            // If multiple instances exist, try to find the one that matches SettingsManager
            if let settingsManager = SettingsManager.instance {
                let expectedKey = "\(settingsManager.accountId)_\(settingsManager.sdkKey)"
                return _instances[expectedKey]
            }
            
            return nil
        }
    }
    
    // Instance methods that prepend instance prefix while using shared LogManager
    // Store ServiceContainer reference for error event sending
    private weak var serviceContainer: ServiceContainer?
    
    func setServiceContainer(_ container: ServiceContainer?) {
        self.serviceContainer = container
    }
    
    func log(level: LogLevelEnum, key: String, details: [String: String]?) {
        // Check log level using instance-specific level before logging
        let configLevel = self.instanceLogLevel
        let requiredLevel = level
        let shouldLogMessage = configLevel.level <= requiredLevel.level
        guard shouldLogMessage else { return }
        
        let logFile = LoggerService.getLogFile(level: level)
        let messageBuilder = LogMessageUtil.buildMessage(template: logFile[key], data: details)
        let finalMessage = instancePrefix.isEmpty ? messageBuilder : "\(instancePrefix): \(messageBuilder ?? "")"
        LogManager.instance?.log(level: level, message: finalMessage, serviceContainer: serviceContainer, skipLevelCheck: true)
    }
    
    func log(level: LogLevelEnum, message: String?) {
        // Check log level using instance-specific level before logging
        let configLevel = self.instanceLogLevel
        let requiredLevel = level
        let shouldLogMessage = configLevel.level <= requiredLevel.level
        guard shouldLogMessage else { return }
        
        let finalMessage = instancePrefix.isEmpty ? message : "\(instancePrefix): \(message ?? "")"
        LogManager.instance?.log(level: level, message: finalMessage, serviceContainer: serviceContainer, skipLevelCheck: true)
    }
}
