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
 * Represents the context for a Wingify user.
 *
 * This class holds information about the user, such as their ID, user agent, IP address,
 * and any custom or variation targeting variables. It also maintains a reference to the
 * Wingify gateway service.
 */
@objc public class WingifyUserContext:NSObject {
    var id: String?
    @objc public var userAgent: String = Constants.USER_AGENT_VALUE
    var ipAddress: String = ""
    var customVariables: [String: Any] = [:]
    var variationTargetingVariables: [String: Any] = [:]
    var vwo: GatewayService?
    var shouldUseDeviceIdAsUserId: Bool = false
    var postSegmentationVariables: [String]? = nil
    /// Optional seed used for consistent bucketing. When set, it is used instead of the user id.
    @objc public var bucketingSeed: String? = nil

    internal lazy var uuid: String = {
        let settingManager = SettingsManager.instance
        let stringAccountId = "\(settingManager?.accountId ?? 0)"

        return UUIDUtils.getUUID(userId: self.id,  accountId: stringAccountId )
    }()

    internal var sessionId: Int64 = FmeConfig.generateSessionId()

    /**
     * Initializes a new instance of WingifyUserContext.
     *
     * - Parameters:
     *   - id: The unique identifier for the user.
     *   - customVariables: A dictionary of custom variables associated with the user.
     *   - shouldUseDeviceIdAsUserId: If true, uses device ID when id is nil.
     *   - postSegmentationVariables: A list of Key variables that addes customVariable for postSegmentaion.
     *   - bucketingSeed: Optional custom seed for bucketing when provided.
     */

    public init(id: String? = nil, shouldUseDeviceIdAsUserId: Bool = false,customVariables: [String: Any], postSegmentationVariables: [String]? = nil, bucketingSeed: String? = nil,ipAddress: String? = nil) {
        self.shouldUseDeviceIdAsUserId = shouldUseDeviceIdAsUserId
        self.customVariables = customVariables
        self.id = id
        self.postSegmentationVariables = postSegmentationVariables
        self.bucketingSeed = bucketingSeed
        self.ipAddress = ipAddress ?? ""
        if shouldUseDeviceIdAsUserId && id == nil {
            if let deviceId = DeviceIDUtil().getDeviceID() {
                self.id = deviceId
                LoggerService.log(level: .info, key: "USER_ID_INFO", details: ["id": deviceId])
            }
        }
    }

    /**
     * Creates an isolated copy for parallel flag evaluation.
     * Each evaluation mutates context maps independently without affecting siblings.
     */
    func clone() -> WingifyUserContext {
        let copy = WingifyUserContext(
            id: id,
            shouldUseDeviceIdAsUserId: shouldUseDeviceIdAsUserId,
            customVariables: customVariables,
            postSegmentationVariables: postSegmentationVariables,
            bucketingSeed: bucketingSeed,
            ipAddress: ipAddress
        )
        copy.userAgent = userAgent
        copy.variationTargetingVariables = variationTargetingVariables
        copy.vwo = vwo.map { gateway in
            var cloned = GatewayService()
            cloned.location = gateway.location
            cloned.userAgent = gateway.userAgent
            return cloned
        }
        copy.sessionId = sessionId
        return copy
    }

}
