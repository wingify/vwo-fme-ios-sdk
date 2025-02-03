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
 * Represents a feature in VWO.
 *
 * This class encapsulates information about a VWO feature, including its key, metrics, status, ID,
 * rules, impact campaign, name, type, linked campaigns, gateway service requirement, and variables.
 */
struct Feature: Codable, Equatable {
    var key: String?
    var metrics: [Metric]?
    var status: String?
    var id: Int?
    var rules: [Rule]?
    var impactCampaign: ImpactCampaign?
    var name: String?
    var type: String?
    var rulesLinkedCampaign: [Campaign]?
    var isGatewayServiceRequired: Bool = false
    var variables: [Variable]?
    
    enum CodingKeys: String, CodingKey {
        case key
        case metrics
        case status
        case id
        case rules
        case impactCampaign
        case name
        case type
        case rulesLinkedCampaign
        case isGatewayServiceRequired
        case variables
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decodeIfPresent(String.self, forKey: .key)
        metrics = try container.decodeIfPresent([Metric].self, forKey: .metrics)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        rules = try container.decodeIfPresent([Rule].self, forKey: .rules)
        impactCampaign = try container.decodeIfPresent(ImpactCampaign.self, forKey: .impactCampaign)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        rulesLinkedCampaign = try container.decodeIfPresent([Campaign].self, forKey: .rulesLinkedCampaign)
        isGatewayServiceRequired = try container.decodeIfPresent(Bool.self, forKey: .isGatewayServiceRequired) ?? false
        variables = try container.decodeIfPresent([Variable].self, forKey: .variables)
    }
}

extension Array where Element == Feature {
    func sortedById() -> [Feature] {
        return self.sorted { (feature1, feature2) -> Bool in
            switch (feature1.id, feature2.id) {
            case let (id1?, id2?):
                return id1 < id2
            case (nil, _?):
                return true
            case (_?, nil):
                return false
            case (nil, nil):
                return false
            }
        }
    }
}
