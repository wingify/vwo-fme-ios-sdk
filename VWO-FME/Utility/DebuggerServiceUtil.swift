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
class DebuggerServiceUtil {
    
    /// Utility functions for handling debugger service operations including
    /// filtering sensitive properties and extracting decision keys.
    
    /// Extracts only the required fields from a decision object.
    /// - Parameter decisionObj: The decision dictionary to extract fields from.
    /// - Returns: A dictionary containing only rolloutKey and experimentKey if they exist.
    static func extractDecisionKeys(decisionObj: [String: Any] = [:]) -> [String: Any] {
        var extractedKeys: [String: Any] = [:]
        
        if let rolloutId = decisionObj["rolloutId"] {
            extractedKeys["rId"] = rolloutId
        }
        
        if let rolloutVariationId = decisionObj["rolloutVariationId"] {
            extractedKeys["rvId"] = rolloutVariationId
        }
        
        if let experimentId = decisionObj["experimentId"] {
            extractedKeys["eId"] = experimentId
        }
        
        if let experimentVariationId = decisionObj["experimentVariationId"] {
            extractedKeys["evId"] = experimentVariationId
        }
        
        return extractedKeys
    }
    
    /// Sends a debug event to VWO.
    /// - Parameter eventProps: The properties for the event.
    static func sendDebugEventToVWO(eventProps: [String: Any] = [:]) {
        
        // Create query parameters
        let properties = NetworkUtil.getEventsBaseProperties(eventName: EventEnum.VWO_DEBUGGER_EVENT.rawValue,visitorUserAgent: nil,ipAddress: nil)
        
        // Create payload
        let payload = NetworkUtil.getDebuggerEventPayload(eventProps: eventProps)
        
        // Send event
        NetworkUtil.sendGatewayEvent(queryParams: properties, payload: payload, eventName: EventEnum.VWO_DEBUGGER_EVENT.rawValue)
        
    }
}
