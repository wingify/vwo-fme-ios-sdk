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

public class FmeConfig {

    /**
     * Internal storage for the current FME session data.
     * This holds the session information for the ongoing session.
     */
    private static var sessionData: FmeSession?
    
    /**
     * Key used to identify the session ID within session data.
     * This is essential for retrieving session data from other SDKs,
     * such as the Mobile Insights SDK. It is used in conjunction with
     * the VWOSessionCallback protocol, which sends this key within a data dictionary.
     */
    private static let sessionIdKey = "sessionId"
    
    /**
     * This property is a flag used to determine if the Mobile Insights (MI) SDK
     * is linked and integrated with the current environment. It plays a crucial
     * role in the FME<>MI SDK integration.
     *
     * Specifically, this flag is used to set the isMII property in the event data
     * for the "vwoVariationShown" event. Such a configuration helps coordinate
     * session data sharing between various SDKs, ensuring that both
     * FME and MI SDKs correctly manage and interpret session-related information.
     */
    private static var isMISdkLinked:Bool = false

    /**
     * Sets the session data for the current FME session.
     *
     * @param sessionData The FmeSession object containing session information.
     */
    public static func setSessionData(_ data: [String: Any]) {
        
        if data.isEmpty {
            LoggerService.log(level: .error, message: "Session data cannot be empty")
            self.isMISdkLinked = false
            return
        }
                
        if data[self.sessionIdKey] == nil {
            LoggerService.log(level: .error, message: "Session data must contain '\(self.sessionIdKey)' key")
            self.isMISdkLinked = false
            return
        }
                
        if let sessionIdValue = data[self.sessionIdKey] as? Int64 {
            if sessionIdValue <= 0 {
                LoggerService.log(level: .error, message: "'\(self.sessionIdKey)' in session data value must be a positive number")
                self.isMISdkLinked = false
                return
            }
            self.sessionData = FmeSession(sessionId: sessionIdValue)
            self.isMISdkLinked = true
        } else {
            LoggerService.log(level: .error, message: "The value for '\(self.sessionIdKey)' in session data must be of type Int64")
            self.isMISdkLinked = false
        }
    }

    /**
     * Generates a session ID for the event.
     * If a session ID is already present in the session data, it will be returned.
     * Otherwise, a new session ID is generated based on the current timestamp.
     *
     * @return The session ID.
     */
    static func generateSessionId() -> Int64 {
        if let sessionId = sessionData?.sessionId, sessionId >= 0 {
            return sessionId
        }
        return Date().currentTimeSeconds()
    }
    
    static func checkIsMILinked() -> Bool {
        return self.isMISdkLinked
    }
}
