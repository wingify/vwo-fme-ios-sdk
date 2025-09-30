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
 * UserIdUtil - Utility class for managing user ID resolution and alias handling
 *
 * This class provides functionality to resolve user IDs by checking for existing aliases
 * and falling back to device IDs when necessary. It handles the complex logic of
 * user identification across different states (logged-in vs logged-out).
 *
 * ## Key Features:
 * - **Alias Resolution**: Automatically resolves temporary IDs to permanent user IDs
 * - **Device ID Fallback**: Uses device ID when no user ID is provided
 * - **Synchronous Interface**: Provides synchronous API despite underlying async operations
 * - **Comprehensive Logging**: Detailed logging for debugging and monitoring
 *

 * ## Thread Safety:
 * This class uses semaphores to make async operations synchronous. Use with caution
 * on the main thread as it may block execution during API calls.
 *
 * @since 1.9.1
 * @author VWO Team
 */
class UserIdUtil {
    
    /**
     * @param context The user context to process and update
     * @return Updated user context with resolved user ID
     */
    func getUserId(context: VWOUserContext) -> VWOUserContext {
        
        let updatedContext = context
        
        if let userId = updatedContext.id {
            
          if  userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty{
                LoggerService.log(level: .error, key: "USERID_CANNOT_BE_BlANK", details: [:])
                return updatedContext
            }
            
            if AliasIdentifierManager.shared.isEnabled ?? false && AliasIdentifierManager.shared.isGatewayEnabled ?? false{
            // Use semaphore to make async call synchronous
            let semaphore = DispatchSemaphore(value: 0)
            var resolvedId: String?

                AliasIdentifierManager.shared.getAliasIfExistsAsync(tempID: userId) { userID in
                    resolvedId = userID ?? userId
                    semaphore.signal()
                }
                
                // Wait for the async call to complete
                semaphore.wait()
                
                if let aliasID = resolvedId {
                    updatedContext.id = aliasID
                    LoggerService.log(level: .info, key: "USER_ID_INFO", details: ["id": aliasID])
                } else {
                    updatedContext.id = userId
                    LoggerService.log(level: .info, key: "USER_ID_INFO", details: ["id": userId])
                }
            }else{
                updatedContext.id = userId
                LoggerService.log(level: .info, key: "USER_ID_INFO", details: ["id": userId])
            }
        } else if updatedContext.shouldUseDeviceIdAsUserId {
            if let deviceId = DeviceIDUtil().getDeviceID() {
                updatedContext.id = deviceId
                LoggerService.log(level: .info, key: "USER_ID_INFO", details: ["id": deviceId])
            }
        } else {
            LoggerService.log(level: .error, message: "USER_ID_NULL")
        }
        
        return updatedContext
    }
    
}
