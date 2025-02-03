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
 * Represents a campaign in VWO.
 *
 * This class encapsulates information about a VWO campaign, including its ID, segments, status,
 * traffic allocation, variations, and other related data.
 */
struct Campaign: Codable, Equatable {
    var isAlwaysCheckSegment: Bool?
    var isUserListEnabled: Bool?
    var id: Int?
    var segments: [String: CodableValue]?
    var ruleKey: String?
    var status: String?
    var percentTraffic: Int?
    var key: String?
    var type: String?
    var name: String?
    var isForcedVariationEnabled: Bool?
    var variations: [Variation]?
    var startRangeVariation: Int
    var endRangeVariation: Int
    var variables: [Variable]?
    var weight: Double

    enum CodingKeys: String, CodingKey {
        case isAlwaysCheckSegment
        case isUserListEnabled
        case id
        case segments
        case ruleKey
        case status
        case percentTraffic
        case key
        case type
        case name
        case isForcedVariationEnabled
        case variations
        case startRangeVariation
        case endRangeVariation
        case variables
        case weight
    }
    
    init(
           isAlwaysCheckSegment: Bool? = false,
           isUserListEnabled: Bool? = false,
           id: Int? = nil,
           segments: [String: CodableValue]? = nil,
           ruleKey: String? = nil,
           status: String? = nil,
           percentTraffic: Int? = nil,
           key: String? = nil,
           type: String? = nil,
           name: String? = nil,
           isForcedVariationEnabled: Bool? = false,
           variations: [Variation]? = nil,
           startRangeVariation: Int = 0,
           endRangeVariation: Int = 0,
           variables: [Variable]? = nil,
           weight: Double = 0.0
       ) {
           self.isAlwaysCheckSegment = isAlwaysCheckSegment
           self.isUserListEnabled = isUserListEnabled
           self.id = id
           self.segments = segments
           self.ruleKey = ruleKey
           self.status = status
           self.percentTraffic = percentTraffic
           self.key = key
           self.type = type
           self.name = name
           self.isForcedVariationEnabled = isForcedVariationEnabled
           self.variations = variations
           self.startRangeVariation = startRangeVariation
           self.endRangeVariation = endRangeVariation
           self.variables = variables
           self.weight = weight
       }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isAlwaysCheckSegment = try container.decodeIfPresent(Bool.self, forKey: .isAlwaysCheckSegment) ?? false
        isUserListEnabled = try container.decodeIfPresent(Bool.self, forKey: .isUserListEnabled) ?? false
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        segments = try container.decodeIfPresent([String: CodableValue].self, forKey: .segments)
        ruleKey = try container.decodeIfPresent(String.self, forKey: .ruleKey)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        percentTraffic = try container.decodeIfPresent(Int.self, forKey: .percentTraffic)
        key = try container.decodeIfPresent(String.self, forKey: .key)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        isForcedVariationEnabled = try container.decodeIfPresent(Bool.self, forKey: .isForcedVariationEnabled) ?? false
        variations = try container.decodeIfPresent([Variation].self, forKey: .variations)
        startRangeVariation = try container.decodeIfPresent(Int.self, forKey: .startRangeVariation) ?? 0
        endRangeVariation = try container.decodeIfPresent(Int.self, forKey: .endRangeVariation) ?? 0
        variables = try container.decodeIfPresent([Variable].self, forKey: .variables)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight) ?? 0.0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isAlwaysCheckSegment, forKey: .isAlwaysCheckSegment)
        try container.encode(isUserListEnabled, forKey: .isUserListEnabled)
        try container.encode(id, forKey: .id)
        try container.encode(segments, forKey: .segments)
        try container.encode(ruleKey, forKey: .ruleKey)
        try container.encode(status, forKey: .status)
        try container.encode(percentTraffic, forKey: .percentTraffic)
        try container.encode(key, forKey: .key)
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(isForcedVariationEnabled, forKey: .isForcedVariationEnabled)
        try container.encode(variations, forKey: .variations)
        try container.encode(startRangeVariation, forKey: .startRangeVariation)
        try container.encode(endRangeVariation, forKey: .endRangeVariation)
        try container.encode(variables, forKey: .variables)
        try container.encode(weight, forKey: .weight)
    }

    /// Sets the properties of this campaign from another campaign object.
    ///
    /// - Parameter model: The campaign object to copy properties from.
    mutating func setModelFromDictionary(_ model: Campaign) {
        self = model
    }
}

extension Array where Element == Campaign {
    func sortedById() -> [Campaign] {
        return self.sorted { (campaign1, campaign2) -> Bool in
            switch (campaign1.id, campaign2.id) {
            case let (id1?, id2?):
                return id1 < id2
            case (nil, _?):
                return false // Change to false to keep nils at the end
            case (_?, nil):
                return true
            case (nil, nil):
                return false
            }
        }
    }
}

