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
 * Represents a holdout group in VWO.
 *
 * This struct encapsulates information about a holdout group, including its ID,
 * targeting segments, traffic percentage, global flag, and associated feature IDs.
 * A holdout group is used to exclude a specific percentage of users from new features
 * to measure the cumulative, long-term impact of product changes.
 */
struct HoldoutGroup: Codable, Equatable {
    var name: String?
    var id: Int?
    var segments: [String: CodableValue]?
    var trafficPercent: Int?
    var isGlobal: Bool?
    var isGatewayServiceRequired: Bool? = false
    var featureIds: [Int]?
    var metrics: [Metrics]?

    enum CodingKeys: String, CodingKey {
        case name
        case id
        case segments
        case trafficPercent = "percentTraffic"
        case isGlobal
        case isGatewayServiceRequired
        case featureIds
        case metrics
    }

    struct Metrics: Codable, Equatable {
        var type: String?
        var id: Int?
        var identifier: String?
    }
}
