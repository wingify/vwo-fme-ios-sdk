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
 * Represents a rule in VWO.
 *
 * This class encapsulates information about a VWO rule, including its rule key, variation ID,
 * campaign ID, and type.
 */
struct Rule: Codable {
    let ruleKey: String?
    let variationId: Int?
    let campaignId: Int?
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case ruleKey
        case variationId
        case campaignId
        case type
    }
    
    init(ruleKey: String? = nil, variationId: Int? = nil, campaignId: Int? = nil, type: String? = nil) {
        self.ruleKey = ruleKey
        self.variationId = variationId
        self.campaignId = campaignId
        self.type = type
    }
}
