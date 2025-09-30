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
 * Request model for setting user alias.
 *
 * This struct represents the request body for the setUserAlias API endpoint.
 */
struct SetUserAliasRequest: Codable {
    /**
     * Temporary ID representing the user in logged out state.
     */
    let tempId: String
    
    /**
     * User ID representing the user in logged in state.
     */
    let userId: String
    
    /**
     * Initializes a new instance of SetUserAliasRequest.
     *
     * - Parameters:
     *   - tempId: The temporary ID for the user in logged out state.
     *   - userId: The user ID for the user in logged in state.
     */
    init(tempId: String, userId: String) {
        self.tempId = tempId
        self.userId = userId
    }
}
