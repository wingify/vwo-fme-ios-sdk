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

class SegmentEvaluator {
    var context: VWOUserContext?
    var settings: Settings?
    var feature: Feature?

    /**
     * Validates if the segmentation defined in the DSL is applicable based on the provided properties.
     * @param dsl The domain-specific language defining the segmentation rules.
     * @param properties The properties against which the DSL rules are evaluated.
     * @return A boolean indicating if the segmentation is valid.
     */
    func isSegmentationValid(dsl: [String: CodableValue], properties: [String: Any]) -> Bool {
        guard let entry = SegmentUtil.getKeyValue(dsl) else { return false }
        let operatorKey = entry.0
        let subDsl = entry.1

        // Evaluate based on the type of segmentation operator
        guard let operatorEnum = SegmentOperatorValueEnum(rawValue: operatorKey) else {
            return false
        }

        switch operatorEnum {
        case .not:
            let result = isSegmentationValid(dsl: subDsl.dictionaryValue ?? [:], properties: properties)
            return !result

        case .and:
            return every(dslNodes: subDsl.arrayValue ?? [], customVariables: properties)

        case .or:
            return some(dslNodes: subDsl.arrayValue ?? [], customVariables: properties)

        case .customVariable:
            return SegmentOperandEvaluator.evaluateCustomVariableDSL(subDsl.dictionaryValue ?? [:], properties, context, feature)

        case .user:
            return SegmentOperandEvaluator.evaluateUserDSL(subDsl.stringValue ?? "", properties, context, feature)

        case .ua:
            return SegmentOperandEvaluator.evaluateUserAgentDSL(subDsl.stringValue ?? "", context)
            
        case .device_model:
            return SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: subDsl.stringValue ?? "", value: DeviceUtil().getDeviceModel())
            
        case .locale:
            return SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: subDsl.stringValue ?? "", value: DeviceUtil().getLocale())
        
        case .app_version:
            return SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: subDsl.stringValue ?? "", value: DeviceUtil().getApplicationVersion())
            
        case .os_version:
            return SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: subDsl.stringValue ?? "", value: DeviceUtil().getOsVersion())
            
        case .manufacturer:
            return SegmentOperandEvaluator.evaluateStringOperandDSL(dslOperandValue: subDsl.stringValue ?? "", value: DeviceUtil().getManufacturer())
            
        default:
            return false
        }
    }

    /**
     * Evaluates if any of the DSL nodes are valid using the OR logic.
     * @param dslNodes Array of DSL nodes to evaluate.
     * @param customVariables Custom variables provided for evaluation.
     * @return A boolean indicating if any of the nodes are valid.
     */
    func some(dslNodes: [CodableValue], customVariables: [String: Any]) -> Bool {
        var uaParserMap = [String: [String]]()
        var keyCount = 0 // Initialize count of keys encountered
        var isUaParser = false

        for dsl in dslNodes {
            guard let dslDict = dsl.dictionaryValue else { continue }
            for (key, value) in dslDict {
                // Check for user agent related keys
                guard let keyEnum = SegmentOperatorValueEnum(rawValue: key) else {
                    continue
                }
                
                if keyEnum == .operatingSystem || keyEnum == .browserAgent || keyEnum == .deviceType || keyEnum == .device {
                    isUaParser = true

                    if uaParserMap[key] == nil {
                        uaParserMap[key] = [String]()
                    }

                    // Ensure value is treated as an array of strings
                    if let arrayValue = value.arrayValue {
                        for val in arrayValue {
                            if let text = val.stringValue {
                                uaParserMap[key]?.append(text)
                            }
                        }
                    } else if let text = value.stringValue {
                        uaParserMap[key]?.append(text)
                    }

                    keyCount += 1 // Increment count of keys encountered
                }

                // Check for feature toggle based on feature ID
                if keyEnum == .featureId {
                    guard let featureIdObject = value.dictionaryValue else { continue }
                    for (featureIdKey, featureIdValue) in featureIdObject {
                        if let featureIdValueText = featureIdValue.stringValue, featureIdValueText == "on" || featureIdValueText == "off" {
                            let features = settings?.features
                            let feature = features?.first { $0.id == Int(featureIdKey) }
                            if let feature = feature, let featureKey = feature.key {
                                if let context = context {
                                    let result = checkInUserStorage(featureKey: featureKey, context: context)
                                    if featureIdValueText == "off" {
                                        return !result
                                    }
                                    return result
                                } else {
                                    return false
                                }
                            } else {
                                LoggerService.errorLog( key: "FEATURE_NOT_FOUND_WITH_ID",data: ["featureIdKey":featureIdKey],
                                                        debugData: [
                                        "an": ApiEnum.getFlag.rawValue,
                                        "uuid": context?.uuid ?? "",
                                        "sId": context?.sessionId ?? FmeConfig.generateSessionId()
                                    ]
                                )
                                return false // Handle the case when feature is not found
                            }
                        }
                    }
                }
            }

            
            // Check if the count of keys encountered is equal to dslNodes.count
            if isUaParser && keyCount == dslNodes.count {
                let uaParserResult = checkUserAgentParser(uaParserMap: uaParserMap)
                return uaParserResult
            }

            // Recursively check each DSL node
            if isSegmentationValid(dsl: dsl.dictionaryValue ?? [:], properties: customVariables) {
                return true
            }
        }
        return false
    }

    /**
     * Evaluates all DSL nodes using the AND logic.
     * @param dslNodes Array of DSL nodes to evaluate.
     * @param customVariables Custom variables provided for evaluation.
     * @return A boolean indicating if all nodes are valid.
     */
    func every(dslNodes: [CodableValue], customVariables: [String: Any]) -> Bool {
        var locationMap = [String: Any]()
        for dsl in dslNodes {
            guard let dslDict = dsl.dictionaryValue else { continue }
            for (key, _) in dslDict {
                // Check if the DSL node contains location-related keys
                guard let keyEnum = SegmentOperatorValueEnum(rawValue: key) else {
                    continue
                }
                if keyEnum == .country || keyEnum == .region || keyEnum == .city {
                    addLocationValuesToMap(dsl: dslDict, locationMap: &locationMap)
                    // Check if the number of location keys matches the number of DSL nodes
                    if locationMap.count == dslNodes.count {
                        return checkLocationPreSegmentation(locationMap: locationMap)
                    }
                    continue
                }
                let res = isSegmentationValid(dsl: dslDict, properties: customVariables)
                if !res {
                    return false
                }
            }
        }
        return true
    }

    /**
     * Adds location values from a DSL node to a map.
     * @param dsl DSL node containing location data.
     * @param locationMap Map to store location data.
     */
    func addLocationValuesToMap(dsl: [String: CodableValue], locationMap: inout [String: Any]) {
        // Add country, region, and city information to the location map if present
        for (key, value) in dsl {
            guard let keyEnum = SegmentOperatorValueEnum(rawValue: key) else {
                continue
            }
            if keyEnum == .country || keyEnum == .region || keyEnum == .city {
                locationMap[keyEnum.rawValue] = value
            }
        }
    }

    /**
     * Checks if the user's location matches the expected location criteria.
     * @param locationMap Map of expected location values.
     * @return A boolean indicating if the location matches.
     */
    func checkLocationPreSegmentation(locationMap: [String: Any]) -> Bool {
        // Check if location data is available and matches the expected values
        guard let location = context?.vwo?.location, !location.isEmpty else {
            return false
        }
        
        return SegmentUtil.valuesMatch(expectedLocationMap: locationMap as! [String: CodableValue], userLocation: location)
    }

    /**
     * Checks if the user's device information matches the expected criteria.
     * @param uaParserMap Map of expected user agent values.
     * @return A boolean indicating if the user agent matches.
     */
    func checkUserAgentParser(uaParserMap: [String: [String]]) -> Bool {
        // Ensure user's user agent is available
        guard let userAgent = context?.userAgent, !userAgent.isEmpty else {
            LoggerService.errorLog(
                key: "USER_AGENT_PRE_SEGMENT_ERROR",data: [:],
                debugData: [
                    "an": ApiEnum.getFlag.rawValue,
                    "uuid": context?.uuid ?? "",
                    "sId": context?.sessionId ?? FmeConfig.generateSessionId()
                ]
            )

            return false
        }
        // Check if user agent data is available and matches the expected values
        guard let userAgentContext = context?.vwo?.userAgent, !userAgentContext.isEmpty else {
            return false
        }

        return SegmentUtil.checkValuePresent(expectedMap: uaParserMap, actualMap: userAgentContext)
    }

    /**
     * Checks if the feature is enabled for the user by querying the storage.
     * @param settings The settings model containing configuration.
     * @param featureKey The key of the feature to check.
     * @param context The context object to check against.
     * @return A boolean indicating if the feature is enabled for the user.
     */
    func checkInUserStorage(featureKey: String, context: VWOUserContext) -> Bool {
        let storageService = StorageService()
        let storedDataMap = storageService.getFeatureFromStorage(featureKey: featureKey, context: context)
        
        guard let storedDataMap = storedDataMap else {
            LoggerService.log(level: .error, key: "STORED_DATA_ERROR", details: ["err": "Stored data map is nil"])
            return false
        }
        return !storedDataMap.isEmpty
    }
}
