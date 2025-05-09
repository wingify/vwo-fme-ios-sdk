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
 * Represents a collection of properties associated with an event or entity.
 *
 * This struct is used to store various properties, including SDK information,
 * variation details, custom event flags, and additional dynamic properties.
 */
struct Props {
    var vwoSdkName: String?
    var vwoSdkVersion: String?
    var vwoEnvKey: String?
    var variation: String?
    var id: Int?
    var isFirst: Int?
    var isMII: Bool?
    var isCustomEvent: Bool?
    var additionalProperties: [String: Any] = [:]
    var product: String?
    var data: [String: Any] = [:]
    var vwoMeta: [String: Any] = [:]
    
    mutating func setSdkName(_ sdkName: String?) {
        self.vwoSdkName = sdkName
    }
    
    mutating func setSdkVersion(_ sdkVersion: String?) {
        self.vwoSdkVersion = sdkVersion
    }
    
    mutating func setIsFirst(_ isFirst: Int?) {
        self.isFirst = isFirst
    }
    
    mutating func setIsCustomEvent(_ isCustomEvent: Bool?) {
        self.isCustomEvent = isCustomEvent
    }
    
    mutating func setEnvKey(_ vwoEnvKey: String?) {
        self.vwoEnvKey = vwoEnvKey
    }
    
    mutating func setProduct(_ product: String?) {
        self.product = product
    }
    
    mutating func setData(_ data: [String: Any]) {
        self.data = data
    }
    
    func getAdditionalProperties() -> [String: Any] {
        return additionalProperties
    }
    
    mutating func setAdditionalProperties(_ additionalProperties: [String: Any]) {
        self.additionalProperties = additionalProperties
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let vwoSdkName = vwoSdkName {
            dict["vwo_sdkName"] = vwoSdkName
        }
        if let vwoSdkVersion = vwoSdkVersion {
            dict["vwo_sdkVersion"] = vwoSdkVersion
        }
        if let vwoEnvKey = vwoEnvKey {
            dict["vwo_envKey"] = vwoEnvKey
        }
        if let variation = variation {
            dict["variation"] = variation
        }
        if let id = id {
            dict["id"] = id
        }
        if let isFirst = isFirst {
            dict["isFirst"] = isFirst
        }
        if let isCustomEvent = isCustomEvent {
            dict["isCustomEvent"] = isCustomEvent
        }
        if let isMII = isMII {
            dict["isMII"] = isMII
        }
        if let product = product {
            dict["product"] = product
        }
        for (key, value) in additionalProperties {
            dict[key] = value
        }
        var tempDict: [String: Any] = [:]
        for (key, value) in data {
            tempDict[key] = value
        }
        if !tempDict.isEmpty {
            dict["data"] = tempDict
        }
        
        if !vwoMeta.isEmpty {
            dict["vwoMeta"] = vwoMeta
        }
        return dict
    }
}
