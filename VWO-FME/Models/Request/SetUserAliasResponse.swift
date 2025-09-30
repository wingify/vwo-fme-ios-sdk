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
 * Response model for setting user alias.
 *
 * This struct represents the response from the setUserAlias API endpoint.
 */
struct SetUserAliasResponse: Codable {
    /**
     * Flag indicating if the alias was successfully set.
     */
    let isAliasSet: Bool
    
    /**
     * Initializes a new instance of SetUserAliasResponse.
     *
     * - Parameters:
     *   - isAliasSet: Flag indicating if the alias was successfully set.
     */
    init(isAliasSet: Bool) {
        self.isAliasSet = isAliasSet
    }
}
