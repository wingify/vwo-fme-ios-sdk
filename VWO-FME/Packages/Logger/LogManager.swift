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
import os
/**
 * Interface for managing log operations.
 *
 * This interface defines methods for configuring and interacting with log transports,
 * as well as for retrieving log-related information such as the current log level,
 * prefix, and date-time format.
 */

internal class LogManager {
    
    static var instance: LogManager?
    
    let dateTimeForm: DateFormatter
    private var transports: [[String: Any]] = []
    var level: LogLevelEnum
    private var tag = "VWO FME Logger"

    init(config: [String: Any]?, logLevel: LogLevelEnum) {
        self.level = logLevel
        self.dateTimeForm = DateFormatter()
        self.dateTimeForm.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        LogManager.instance = self
    }
    
    private func getDateAndTime() -> String {
        
        let now = Date()
        let dateString = self.dateTimeForm.string(from: now)
        return dateString
    }
    
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
        let formatMessage = "\(tag): \(level.levelIndicator): \(message ?? "")"
        os_log("%{public}@", log: OSLog(subsystem: tag, category: level.rawValue), type: osLogType, formatMessage)
    }
    
    func log(level: LogLevelEnum, message: String?) {
        guard let message = message else { return }
        let configLevel = self.level
        let requiredLevel = level
        let shouldLogMessage = configLevel.level <= requiredLevel.level
        if shouldLogMessage {
            self.logMessage(level: level, message: message)
        }
    }
}
