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
@objc public class VWOUserContext:NSObject {
    var id: String?
    var userAgent: String = Constants.USER_AGENT_VALUE
    var ipAddress: String = ""
    var customVariables: [String: Any] = [:]
    var variationTargetingVariables: [String: Any] = [:]
    var vwo: GatewayService?
    var shouldUseDeviceIdAsUserId: Bool = false
    var postSegmentationVariables: [String]? = nil

    internal lazy var uuid: String = {
        let settingManager = SettingsManager.instance
        let stringAccountId = "\(settingManager?.accountId ?? 0)"

        return UUIDUtils.getUUID(userId: self.id,  accountId: stringAccountId )
    }()

    internal var sessionId: Int64 = FmeConfig.generateSessionId()

    /**
     * Initializes a new instance of VWOUserContext.
     *
     * - Parameters:
     *   - id: The unique identifier for the user.
     *   - customVariables: A dictionary of custom variables associated with the user.
     *   - shouldUseDeviceIdAsUserId: If true, uses device ID when id is nil.
     *   - postSegmentationVariables: A list of Key variables that addes customVariable for postSegmentaion.
     */

    public init(id: String? = nil, shouldUseDeviceIdAsUserId: Bool = false,customVariables: [String: Any], postSegmentationVariables: [String]? = nil) {
        self.shouldUseDeviceIdAsUserId = shouldUseDeviceIdAsUserId
        self.customVariables = customVariables
        self.id = id
        self.postSegmentationVariables = postSegmentationVariables
        if shouldUseDeviceIdAsUserId && id == nil {
            if let deviceId = DeviceIDUtil().getDeviceID() {
                self.id = deviceId
                LoggerService.log(level: .info, key: "USER_ID_INFO", details: ["id": deviceId])
            }
        }
    }

}
