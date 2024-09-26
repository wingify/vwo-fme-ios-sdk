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
/**
 * Enumeration representing log levels.
 *
 * This enum defines constants for different log levels used for logging messages
 * within the application. Each log level is associated with a specific string value.
 */
public enum LogLevelEnum: String {
    /**
     * Log level for detailed tracing information.
     */
    case trace = "TRACE"
    
    /**
     * Log level for debugging information.
     */
    case debug = "DEBUG"
    
    /**
     * Log level for general informational messages.
     */
    case info = "INFO"
    
    /**
     * Log level for warning messages.
     */
    case warn = "WARN"
    
    /**
     * Log level for error messages.
     */
    case error = "ERROR"
        
    internal var level: Int {
        switch self {
        case .trace: return 0
        case .debug: return 1
        case .info: return 2
        case .warn: return 3
        case .error: return 4
        }
    }
    
    internal var levelIndicator: String {
        switch self {
        case .trace: return "🔍 [Trace]"
        case .debug: return "🐛 [Debug]"
        case .info: return "ℹ️ [Info]"
        case .warn: return "⚠️ [Warn]"
        case .error: return "❗️[Error]"
        }
    }
}
