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
 * Represents the context for a VWO user.
 *
 * This class holds information about the user, such as their ID, user agent, IP address,
 * and any custom or variation targeting variables. It also maintains a reference to the
 * VWO gateway service.
 */
public class VWOContext {
    var id: String?
    var userAgent: String = ""
    var ipAddress: String = ""
    var customVariables: [String: Any] = [:]
    var variationTargetingVariables: [String: Any] = [:]
    var vwo: GatewayService?
    
    /**
     * Initializes a new instance of VWOContext.
     *
     * - Parameters:
     *   - id: The unique identifier for the user.
     *   - customVariables: A dictionary of custom variables associated with the user.
     *   - ipAddress: The IP address of the user. Defaults to an empty string.
     *   - userAgent: The user agent string of the user's browser. Defaults to an empty string.
     */
    public init(id: String?, customVariables: [String: Any], ipAddress: String = "", userAgent: String = "") {
        self.id = id
        self.customVariables = customVariables
        self.ipAddress = ipAddress
        self.userAgent = userAgent
    }
}
