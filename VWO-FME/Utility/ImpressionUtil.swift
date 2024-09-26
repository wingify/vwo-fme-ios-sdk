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
 * Utility class for impression-related operations.
 *
 * This class provides helper methods for managing and tracking impressions, such as recording
 * impression events, calculating impression counts, or handling impression-related data.
 */
class ImpressionUtil {
    
    /**
     * Creates and sends an impression for a variation shown event.
     * This function constructs the necessary properties and payload for the event
     * and uses the NetworkUtil to send a POST API request.
     *
     * - Parameters:
     *   - settings: The settings model containing configuration.
     *   - campaignId: The ID of the campaign.
     *   - variationId: The ID of the variation shown to the user.
     *   - context: The user context model containing user-specific data.
     */
    static func createAndSendImpressionForVariationShown(
        settings: Settings,
        campaignId: Int,
        variationId: Int,
        context: VWOContext
    ) {
        // Get base properties for the event
        let properties = NetworkUtil.getEventsBaseProperties(
            setting: settings,
            eventName: EventEnum.vwoVariationShown.rawValue,
            visitorUserAgent: encodeURIComponent(context.userAgent),
            ipAddress: context.ipAddress
        )
        
        // Construct payload data for tracking the user
        let payload = NetworkUtil.getTrackUserPayloadData(
            settings: settings,
            userId: context.id,
            eventName: EventEnum.vwoVariationShown.rawValue,
            campaignId: campaignId,
            variationId: variationId,
            visitorUserAgent: context.userAgent,
            ipAddress: context.ipAddress
        )
        
        // Send the constructed properties and payload as a POST request
        NetworkUtil.sendPostApiRequest(
            properties: properties,
            payload: payload,
            userAgent: context.userAgent,
            ipAddress: context.ipAddress
        )
    }
    
    /**
     * Encodes the query parameters to ensure they are URL-safe
     * - Parameter value: The query parameters to encode
     * - Returns: The encoded query parameters
     */
    static func encodeURIComponent(_ value: String) -> String {
        return value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}
