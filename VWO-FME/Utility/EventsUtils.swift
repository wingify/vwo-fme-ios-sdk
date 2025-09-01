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
    * Sends an init event to VWO.
    * This event is triggered when the init function is called.
    * @param settingsFetchTime Time taken to fetch settings in milliseconds.
    * @param sdkInitTime Time taken to initialize the SDK in milliseconds.
    */
class EventsUtils {
    
    func sendSdkInitEvent(settingsFetchTime: Int64? = nil, sdkInitTime: Int64? = nil) {
        // Create the query parameters
        let queryParams = NetworkUtil.getEventsBaseProperties(eventName: EventEnum.VWO_INIT_CALLED.rawValue, visitorUserAgent: nil, ipAddress: nil)

        // Create the payload with required fields
        let payload = NetworkUtil.getSDKInitEventPayload(eventName: EventEnum.VWO_INIT_CALLED.rawValue, settingsFetchTime: settingsFetchTime, sdkInitTime: sdkInitTime)

        // Send the constructed payload via POST request
        NetworkUtil.sendGatewayEvent(queryParams: queryParams, payload: payload)
    }

    /// Sends a usage stats event to VWO.
    /// This event is triggered when the SDK is initialized.
    ///
    /// - Parameter usageStatsAccountId: The account ID specifically designated for tracking usage statistics.
    ///                                  This might be different from the main VWO account ID.
    func sendSDKUsageStatsEvent(usageStatsAccountId: Int) {
        // Create the query parameters
        let queryParams = NetworkUtil.getEventsBaseProperties(
            eventName: EventEnum.VWO_USAGE_STATS.rawValue,
            visitorUserAgent: nil,
            ipAddress: nil,
            isUsageStatsEvent: true,
            usageStatsAccountId: usageStatsAccountId
        )
        
        // Create the payload with required fields
        let payload = NetworkUtil.getSDKUsageStatsEventPayload(
            event: EventEnum.VWO_USAGE_STATS,
            usageStatsAccountId: usageStatsAccountId
        )
        
        // Send the payload as a POST request
        NetworkUtil.sendGatewayEvent(queryParams: queryParams, payload: payload)
    }

}
