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

class SetAttributeAPI {
    /**
     * This method is used to set an attribute for the user.
     * @param settings The settings model containing configuration.
     * @param attributeKey The key of the attribute to set.
     * @param attributeValue The value of the attribute to set.
     * @param context  The user context model containing user-specific data.
     */
    static func setAttribute(settings: Settings, attributeKey: String, attributeValue: Any, context: VWOContext) {
        createAndSendImpressionForSetAttribute(settings: settings, attributeKey: attributeKey, attributeValue: attributeValue, context: context)
    }

    /**
     * Creates and sends an impression for a track event.
     * This function constructs the necessary properties and payload for the event
     * and uses the NetworkUtil to send a POST API request.
     *
     * @param settings   The settings model containing configuration.
     * @param attributeKey  The key of the attribute to set.
     * @param attributeValue  The value of the attribute to set.
     * @param context    The user context model containing user-specific data.
     */
    private static func createAndSendImpressionForSetAttribute(
        settings: Settings,
        attributeKey: String,
        attributeValue: Any,
        context: VWOContext
    ) {
        // Get base properties for the event
        let properties = NetworkUtil.getEventsBaseProperties(
            setting: settings,
            eventName: EventEnum.vwoSyncVisitorProp.rawValue,
            visitorUserAgent: ImpressionUtil.encodeURIComponent(context.userAgent),
            ipAddress: context.ipAddress
        )

        // Construct payload data for tracking the user
        let payload = NetworkUtil.getAttributePayloadData(
            settings: settings,
            userId: context.id,
            eventName: EventEnum.vwoSyncVisitorProp.rawValue,
            attributeKey: attributeKey,
            attributeValue: attributeValue
        )

        // Send the constructed properties and payload as a POST request
        NetworkUtil.sendPostApiRequest(properties: properties, payload: payload, userAgent: context.userAgent, ipAddress: context.ipAddress)
    }
}
