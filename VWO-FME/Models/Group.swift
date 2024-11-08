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
 * Represents a group of campaigns in VWO.
 *
 * This class encapsulates information about a group of VWO campaigns, including its name, associated campaigns, and settings for experiment type, priority, and weight.
 */
struct Groups: Codable, Equatable {
    var name: String?
    var campaigns: [String]?
    var et: Int?
    var p: [String]?
    var wt: [String: Double]?

    enum CodingKeys: String, CodingKey {
        case name
        case campaigns
        case et
        case p
        case wt
    }
    
    /**
     * Sets the experiment type for the group.
     *
     * @param et The experiment type.
     */
    mutating func setEt(_ et: Int) {
        self.et = et
    }
    
    /**
     * Gets the experiment type for the group.
     *
     * @return The experiment type. Defaults to 1 (random) if not set.
     */
    func getEt() -> Int {
        // set default to random
        return et ?? 1
    }
}
