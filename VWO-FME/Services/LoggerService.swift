/**
 * Copyright 2024 Wingify Software Pvt. Ltd.
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
    
    private static var debugMessages: [String: String] = [:]
    private static var errorMessages: [String: String] = [:]
    private static var infoMessages: [String: String] = [:]
    private static var warningMessages: [String: String] = [:]
    private static var traceMessages: [String: String] = [:]
    
    init(config: [String: Any], logLevel: LogLevelEnum) {
        // Initialize the LogManager
        _ = LogManager(config: config, logLevel: logLevel)
        
        // Read the log files
        LoggerService.debugMessages = readLogFiles(fileName: "debug-messages.json")
        LoggerService.infoMessages = readLogFiles(fileName: "info-messages.json")
        LoggerService.errorMessages = readLogFiles(fileName: "error-messages.json")
        LoggerService.warningMessages = readLogFiles(fileName: "warn-messages.json")
        LoggerService.traceMessages = readLogFiles(fileName: "trace-messages.json")
    }
    
    /**
     * Reads the log files and returns the messages in a dictionary.
     */
    private func readLogFiles(fileName: String) -> [String: String] {
        do {
            let bundle = Bundle(for: type(of: self))
            if let path = bundle.path(forResource: fileName, ofType: nil) {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    return json as? [String: String] ?? [:]
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        return [:]
    }
    
    private static func getLogFile(level: LogLevelEnum) -> [String: String] {
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
    
    static func log(level: LogLevelEnum, message: String?) {
        guard let logManager = LogManager.instance else { return }
        logManager.log(level: level, message: message)
    }
}