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
 * Response model for getting user alias.
 *
 * This struct represents the response from the getUserAlias API endpoint.
 * The new response format is an array of objects containing aliasId and userId.
 */
struct GetUserAliasResponse: Codable {
    /**
     * Array of alias mappings containing aliasId and userId pairs.
     */
    let aliasMappings: [AliasMapping]
    
    /**
     * Initializes a new instance of GetUserAliasResponse.
     *
     * - Parameter aliasMappings: Array of alias mappings.
     */
    init(aliasMappings: [AliasMapping]) {
        self.aliasMappings = aliasMappings
    }
    
    /**
     * Convenience initializer for backward compatibility.
     * Creates a response with a single alias mapping.
     *
     * - Parameter aliasId: The alias ID.
     */
    init(aliasId: String) {
        self.aliasMappings = [AliasMapping(aliasId: aliasId, userId: "")]
    }
}

/**
 * Individual alias mapping containing aliasId and userId.
 */
struct AliasMapping: Codable {
    /**
     * The alias ID (userId1, tempId2, etc.).
     */
    let aliasId: String
    
    /**
     * The user ID (tempId1, etc.).
     */
    let userId: String
    
    /**
     * Initializes a new instance of AliasMapping.
     *
     * - Parameters:
     *   - aliasId: The alias ID.
     *   - userId: The user ID.
     */
    init(aliasId: String, userId: String) {
        self.aliasId = aliasId
        self.userId = userId
    }
}
