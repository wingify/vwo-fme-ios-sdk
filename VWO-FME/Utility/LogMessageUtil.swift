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

/**
 * Utility struct for log message operations.
 *
 * This class provides helper methods for formatting and processing log messages, such as
 * constructing log messages with dynamic data, adding timestamps, or applying formatting rules.
 */
class LogMessageUtil {
    private static let NARGS = try! NSRegularExpression(pattern: "\\{([0-9a-zA-Z_]+)\\}", options: [])
    
    /**
     * Constructs a message by replacing placeholders in a template with corresponding values from a data object.
     *
     * - Parameters:
     *   - template: The message template containing placeholders in the format {key}.
     *   - data: A dictionary containing keys and values used to replace the placeholders in the template.
     * - Returns: The constructed message with all placeholders replaced by their corresponding values from the data object.
     */
    
    static func buildMessage(template: String?, data: [String: String]?) -> String? {
        guard let template = template, let data = data else {
            return template
        }
        let result = NSMutableString(string: template)
        let matches = NARGS.matches(in: template, options: [], range: NSRange(location: 0, length: template.utf16.count))
        for match in matches.reversed() {
            if let keyRange = Range(match.range(at: 1), in: template) {
                let key = String(template[keyRange])
                if let value = data[key] {
                    result.replaceCharacters(in: match.range, with: NSRegularExpression.escapedTemplate(for: value))
                }
            }
        }
        return result as String
        
    }
}
