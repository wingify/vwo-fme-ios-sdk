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
 * Represents VWO settings.
 *
 * This class serves as a container for various settings and configurations used by the VWO SDK.
 */
struct Settings: Codable {
    var features: [Feature] = []
    var accountId: Int?
    var groups: [String: Groups]?
    var campaignGroups: [String: Int]?
    var isNBv2: Bool = false
    var campaigns: [Campaign]?
    var isNB: Bool = false
    var sdkKey: String?
    var version: Int?
    var collectionPrefix: String?
    
    enum CodingKeys: String, CodingKey {
        case features
        case accountId
        case groups
        case campaignGroups
        case isNBv2
        case campaigns
        case isNB
        case sdkKey
        case version
        case collectionPrefix
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let featuresArray = try? container.decodeIfPresent([Feature].self, forKey: .features) {
            features = featuresArray
        } else {
            features = []
        }
        accountId = try container.decodeIfPresent(Int.self, forKey: .accountId)
        groups = try container.decodeIfPresent([String: Groups].self, forKey: .groups)
        campaignGroups = try container.decodeIfPresent([String: Int].self, forKey: .campaignGroups)
        isNBv2 = try container.decodeIfPresent(Bool.self, forKey: .isNBv2) ?? false
        if let campaignsArray = try? container.decodeIfPresent([Campaign].self, forKey: .campaigns) {
            campaigns = campaignsArray
        } else {
            campaigns = []
        }
        isNB = try container.decodeIfPresent(Bool.self, forKey: .isNB) ?? false
        sdkKey = try container.decodeIfPresent(String.self, forKey: .sdkKey)
        version = try container.decodeIfPresent(Int.self, forKey: .version)
        collectionPrefix = try container.decodeIfPresent(String.self, forKey: .collectionPrefix)
    }
}
