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
 * Represents stored data for a VWO user.
 *
 * This class encapsulates information about a VWO user's assigned variations and rollout
 * information, which is typically persisted in storage.
 */
struct Storage: Codable {
    var featureKey: String?
    var user: String?
    var rolloutId: Int?
    var rolloutKey: String?
    var rolloutVariationId: Int?
    var experimentId: Int?
    var experimentKey: String?
    var experimentVariationId: Int?
    /// Decision expiry time in milliseconds (timestamp when decision becomes invalid). Nil or non-positive = valid indefinitely.
    var decisionExpiryTime: Int64?

    /// Returns true when the stored decision has expired (decisionExpiryTime is a positive timestamp in the past).
    func isDecisionExpired() -> Bool {
        guard let expiry = decisionExpiryTime, expiry > 0 else { return false }
        return Date().currentTimeMillis() > expiry
    }
}
