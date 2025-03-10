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

class TrackEventAPI {
    /**
     * This method is used to track an event for the user.
     * @param settings The settings model containing configuration.
     * @param eventName The name of the event to track.
     * @param context The user context model containing user-specific data.
     * @param eventProperties event properties for the event
     * @param hooksManager The hooks manager instance.
     * @return Boolean indicating if the event was successfully tracked.
     */
    static func track(
        settings: Settings,
        eventName: String,
        context: VWOContext,
        eventProperties: [String: Any],
        hooksManager: HooksManager
    ) {
        let doesEventBelongToAnyFeature = FunctionUtil.doesEventBelongToAnyFeature(eventName: eventName, settings: settings)
        if doesEventBelongToAnyFeature {
            createAndSendImpressionForTrack(settings: settings, eventName: eventName, context: context, eventProperties: eventProperties)
            var objectToReturn: [String: Any] = [:]
            objectToReturn["eventName"] = eventName
            objectToReturn["api"] = ApiEnum.track.rawValue
            hooksManager.set(properties: objectToReturn)
            hooksManager.execute(properties: hooksManager.get())
        } else {
            LoggerService.log(level: .error, key: "EVENT_NOT_FOUND", details: ["eventName": eventName])
        }
    }

    /**
     * Creates and sends an impression for a track event.
     * This function constructs the necessary properties and payload for the event
     * and uses the NetworkUtil to send a POST API request.
     *
     * @param settings   The settings model containing configuration.
     * @param eventName  The name of the event to track.
     * @param context    The user context model containing user-specific data.
     * @param eventProperties event properties for the event
     */
    private static func createAndSendImpressionForTrack(
        settings: Settings,
        eventName: String,
        context: VWOContext,
        eventProperties: [String: Any]
    ) {
        // Get base properties for the event
        let properties = NetworkUtil.getEventsBaseProperties(
            eventName: eventName,
            visitorUserAgent: ImpressionUtil.encodeURIComponent(context.userAgent),
            ipAddress: context.ipAddress
        )

        // Construct payload data for tracking the user
        let payload = NetworkUtil.getTrackGoalPayloadData(
            settings: settings,
            userId: context.id,
            eventName: eventName,
            context: context,
            eventProperties: eventProperties
        )

        // Send the constructed properties and payload as a POST request
        NetworkUtil.sendPostApiRequest(properties: properties, payload: payload, userAgent: context.userAgent, ipAddress: context.ipAddress)
    }
}
