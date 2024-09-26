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
 * Event architecture data
 */

import Foundation

/**
 * Event architecture data
 *
 * @constructor Create empty Event arch data
 */
struct EventArchData {
    var msgId: String?
    var visId: String?
    var sessionId: Int64?
    var event: Event?
    var visitor: Visitor?
    var visitorUserAgent: String?
    var visitorIpAddress: String?
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let msgId = msgId { dict["msgId"] = msgId }
        if let visId = visId { dict["visId"] = visId }
        if let sessionId = sessionId { dict["sessionId"] = sessionId }
        if let event = event { dict["event"] = event.toDictionary() }
        if let visitor = visitor { dict["visitor"] = visitor.toDictionary() }
        if let visitorUa = visitorUserAgent { dict["visitor_ua"] = visitorUa }
        if let visitorIp = visitorIpAddress { dict["visitor_ip"] = visitorIp }
        return dict
    }
}
