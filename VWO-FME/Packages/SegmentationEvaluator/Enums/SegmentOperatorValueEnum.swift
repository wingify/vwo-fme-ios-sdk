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
 * Values for segment operators.
 *
 * This enum defines string values associated with different types of segment operators. These values can be used for identifying and processing specific operators within segmentation rules.
 */
enum SegmentOperatorValueEnum: String {
    case and = "and"
    case not = "not"
    case or = "or"
    case customVariable = "custom_variable"
    case user = "user"
    case country = "country"
    case region = "region"
    case city = "city"
    case operatingSystem = "os"
    case deviceType = "device_type"
    case browserAgent = "browser_string"
    case ua = "ua"
    case device = "device"
    case featureId = "featureId"

    /**
     * Retrieves the enum constant for the given value.
     *
     * @param value The string value representing the operator.
     * @return The corresponding enum constant.
     * @throws IllegalArgumentException if no enum constant with the given value exists.
     */
    static func fromValue(_ value: String) throws -> SegmentOperatorValueEnum {
        if let operatorValue = SegmentOperatorValueEnum(rawValue: value) {
            return operatorValue
        }
        throw NSError(domain: "SegmentOperatorValueEnum", code: -1, userInfo: [NSLocalizedDescriptionKey: "No enum constant with value \(value)"])
    }
}
