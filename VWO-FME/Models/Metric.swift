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
 * Represents a metric in VWO.
 *
 * This struct encapsulates information about a VWO metric, including its various properties such as
 * `mca`, `hasProps`, `identifier`, `id`, and `type`.
 */
struct Metric: Codable, Equatable {
    var mca: Int?
    var hasProps: Bool?
    var identifier: String?
    var id: Int?
    var type: String?
    
    enum CodingKeys: String, CodingKey {
        case mca
        case hasProps = "hasProps"
        case identifier
        case id
        case type
    }
}
