/**
 * Copyright 2024-2026 Wingify Software Pvt. Ltd.
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
    private static let placeholderRegex = try! NSRegularExpression(pattern: "\\{([0-9a-zA-Z_]+)\\}", options: [])
    /// Serializes message construction — parallel getFlags workers log concurrently.
    private static let buildLock = NSLock()

    /**
     * Constructs a message by replacing placeholders in a template with corresponding values from a data object.
     *
     * - Parameters:
     *   - template: The message template containing placeholders in the format {key}.
     *   - data: A dictionary containing keys and values used to replace the placeholders in the template.
     * - Returns: The constructed message with all placeholders replaced by their corresponding values from the data object.
     */
    static func buildMessage(template: String?, data: [String: Any?]?) -> String? {
        buildLock.lock()
        defer { buildLock.unlock() }
        return buildMessageUnlocked(template: template, data: data)
    }

    /// Convenience overload for non-optional dictionary values used by most call sites.
    static func buildMessage(template: String?, data: [String: Any]?) -> String? {
        guard let data = data else {
            return buildMessage(template: template, data: nil as [String: Any?]?)
        }
        var optionalData: [String: Any?] = [:]
        optionalData.reserveCapacity(data.count)
        for (key, value) in data {
            optionalData[key] = value
        }
        return buildMessage(template: template, data: optionalData)
    }

    /// Convenience overload for `[String: String]` detail maps from LoggerService.
    static func buildMessage(template: String?, data: [String: String]?) -> String? {
        guard let data = data else {
            return buildMessage(template: template, data: nil as [String: Any?]?)
        }
        var optionalData: [String: Any?] = [:]
        optionalData.reserveCapacity(data.count)
        for (key, value) in data {
            optionalData[key] = value
        }
        return buildMessage(template: template, data: optionalData)
    }

    private static func buildMessageUnlocked(template: String?, data: [String: Any?]?) -> String? {
        guard let template = template else {
            return nil
        }
        guard let data = data else {
            return template
        }

        // Pure-Swift replacement with guarded ranges — never traps on bad match indexes.
        let nsTemplate = template as NSString
        let matches = placeholderRegex.matches(
            in: template,
            options: [],
            range: NSRange(location: 0, length: nsTemplate.length)
        )

        var result = template
        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else { continue }
            let keyRange = match.range(at: 1)
            guard keyRange.location != NSNotFound,
                  let swiftKeyRange = Range(keyRange, in: template),
                  let fullRange = Range(match.range, in: result) else {
                continue
            }
            let key = String(template[swiftKeyRange])
            guard let value = data[key] else { continue }
            let replacement = String(describing: value ?? "")
            result.replaceSubrange(fullRange, with: replacement)
        }
        return result
    }
    
    /**
     * Sends a messaging event with a specified message.
     *
     * - Parameters:
     *   - message: The message to be sent as part of the event.
     *   - serviceContainer: Optional ServiceContainer to use for error event sending (for multi-instance support).
     *
     * This method constructs the necessary properties and payload for the event using utility functions,
     * and then sends the event using the `NetworkUtil.sendMessagingEvent` method.
     * The event is categorized as an "error" type and uses the `vwoError` enum value as event name.
     */
    static func sendMessageEvent(message: String, serviceContainer: ServiceContainer? = nil) {
        let properties = NetworkUtil.getEventsBaseProperties(eventName: EventEnum.vwoError.rawValue, visitorUserAgent: "", ipAddress: nil, serviceContainer: serviceContainer)
        let payload = NetworkUtil.getMessagingEventPayload(messageType: "error", message: message, eventName: EventEnum.vwoError.rawValue, serviceContainer: serviceContainer)
        NetworkUtil.sendMessagingEvent(properties: properties, payload: payload, serviceContainer: serviceContainer)
    }
    
}
