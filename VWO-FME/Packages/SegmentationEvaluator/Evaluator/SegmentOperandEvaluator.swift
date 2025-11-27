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

class SegmentOperandEvaluator {

    static private var OPERAND_VALUE = "operandValue"

    static private var OPERAND_TYPE = "operandType"

    static private var TAG_VALUE = "tagValue"
    
    /**
     * Evaluates a custom variable DSL operand against user properties.
     *
     * @param dslOperandValue The DSL operand value as a dictionary.
     * @param properties The user properties to evaluate against.
     * @return `true` if the operand matches the user properties, `false` otherwise.
     */
    
    static func evaluateCustomVariableDSL(_ dslOperandValue: [String: CodableValue], _ properties: [String: Any], _ context: VWOUserContext?, _ feature: Feature?) -> Bool {
        guard let userId = context?.id else { return false }
        guard let entry = SegmentUtil.getKeyValue(dslOperandValue) else { return false }
        let operandKey = entry.0
        let operandValueNode = entry.1
        let operandValue = operandValueNode.stringValue ?? ""

        // Check if the property exists
        guard let tagValue = properties[operandKey] else {
            return false
        }

        // Handle 'inlist' operand
        if operandValue.contains("inlist") {
            let listIdPattern = try? NSRegularExpression(pattern: "inlist\\(([^)]+)\\)")
            let matches = listIdPattern?.matches(in: operandValue, options: [], range: NSRange(location: 0, length: operandValue.utf16.count))
            guard let match = matches?.first, let range = Range(match.range(at: 1), in: operandValue) else {
                LoggerService.errorLog(key: "INVALID_ATTRIBUTE_LIST_FORMAT",data:[:] ,debugData: ["an":ApiEnum.getFlag.rawValue,"uuid": context?.uuid ?? "","sId": context?.sessionId ?? 0])
                return false
            }
            let listId = String(operandValue[range])
            // Process the tag value and prepare query parameters
            let attributeValue = preProcessTagValue(tagValue as! String)
            
            var result = false
            checkAttributeInList(listId: listId, attributeValue: attributeValue, userId: userId, featureKey: feature?.key ?? "", customVariable: true, context: context) { booleanValue in
                result = booleanValue
            }
            return result
        } else {
            // Process other types of operands
            var tagValue = properties[operandKey] ?? ""
            tagValue = preProcessTagValue("\(tagValue)")
            let preProcessOperandValue = preProcessOperandValue(operandValue)
            var processedValues = processValues(preProcessOperandValue["operandValue"] as! String, tagValue as! String)

            
            // Convert numeric values to strings if processing wildcard pattern
            let operandType = preProcessOperandValue[OPERAND_TYPE] as? SegmentOperandValueEnum
            
            if operandType == .startingEndingStarValue || operandType == .startingStarValue || operandType == .endingStarValue || operandType == .regexValue {
                let valueForKey = "\(processedValues[TAG_VALUE] ?? "")"
                processedValues[TAG_VALUE] = valueForKey
            }
            tagValue = processedValues[TAG_VALUE] as! String
            return extractResult(operandType, processedValues["operandValue"] as! String, tagValue as! String)
        }
    }

    /**
     * Pre-processes the operand value to determine the operand type and extract the value.
     *
     * @param operand The operand value to pre-process.
     * @return A map containing the operand type and the extracted operand value.
     */
    static func preProcessOperandValue(_ operand: String) -> [String: Any?] {
        var operandType: SegmentOperandValueEnum
        var operandValue: String?

        if SegmentUtil.matchWithRegex(string: operand, regex: SegmentOperandRegexEnum.lowerMatch.rawValue) {
            operandType = .lowerValue
            operandValue = extractOperandValue(operand, SegmentOperandRegexEnum.lowerMatch.rawValue)
        } else if SegmentUtil.matchWithRegex(string: operand, regex: SegmentOperandRegexEnum.wildcardMatch.rawValue) {
            operandValue = extractOperandValue(operand, SegmentOperandRegexEnum.wildcardMatch.rawValue)
            let startingStar = SegmentUtil.matchWithRegex(string: operandValue!, regex: SegmentOperandRegexEnum.startingStar.rawValue)
            let endingStar = SegmentUtil.matchWithRegex(string: operandValue!, regex: SegmentOperandRegexEnum.endingStar.rawValue)
            operandType = startingStar && endingStar ? .startingEndingStarValue : startingStar ? .startingStarValue : endingStar ? .endingStarValue : .regexValue
            
            operandValue = operandValue?.replacingOccurrences(of: .startingStar, with: "").replacingOccurrences(of: .endingStar, with: "")
        } else if SegmentUtil.matchWithRegex(string: operand, regex: SegmentOperandRegexEnum.regex.rawValue) {
            operandType = .regexValue
            operandValue = extractOperandValue(operand, SegmentOperandRegexEnum.regexMatch.rawValue)
        } else if SegmentUtil.matchWithRegex(string: operand, regex: SegmentOperandRegexEnum.greaterThanMatch.rawValue) {
            operandType = .greaterThanValue
            operandValue = extractOperandValue(operand, SegmentOperandRegexEnum.greaterThanMatch.rawValue)
        } else if SegmentUtil.matchWithRegex(string: operand, regex: SegmentOperandRegexEnum.greaterThanEqualToMatch.rawValue) {
            operandType = .greaterThanEqualToValue
            operandValue = extractOperandValue(operand, SegmentOperandRegexEnum.greaterThanEqualToMatch.rawValue)
        } else if SegmentUtil.matchWithRegex(string: operand, regex: SegmentOperandRegexEnum.lessThanMatch.rawValue) {
            operandType = .lessThanValue
            operandValue = extractOperandValue(operand, SegmentOperandRegexEnum.lessThanMatch.rawValue)
        } else if SegmentUtil.matchWithRegex(string: operand, regex: SegmentOperandRegexEnum.lessThanEqualToMatch.rawValue) {
            operandType = .lessThanEqualToValue
            operandValue = extractOperandValue(operand, SegmentOperandRegexEnum.lessThanEqualToMatch.rawValue)
        } else {
            operandType = .equalValue
            operandValue = operand
        }

        return [OPERAND_TYPE: operandType, OPERAND_VALUE: operandValue]
    }

    /**
     * Evaluates a user DSL operand against user properties.
     *
     * @param dslOperandValue The DSL operand value as a string.
     * @param properties The user properties to evaluate against.
     * @return `true` if the operand matches the user properties, `false` otherwise.
     */
    static func evaluateUserDSL(_ dslOperandValue: String, _ properties: [String: Any], _ context: VWOUserContext?, _ feature: Feature?) -> Bool {
        
        guard let userId = context?.id else {
            return false
        }

        if dslOperandValue.contains("inlist") {
            let operandValue = dslOperandValue
            let listIdPattern = try? NSRegularExpression(pattern: "inlist\\(([^)]+)\\)")
            let matches = listIdPattern?.matches(in: operandValue, options: [], range: NSRange(location: 0, length: operandValue.utf16.count))
            guard let match = matches?.first, let range = Range(match.range(at: 1), in: operandValue) else {
                LoggerService.errorLog(
                    key: "INVALID_ATTRIBUTE_LIST_FORMAT",
                    data: [:],
                    debugData: [
                        "an": ApiEnum.getFlag.rawValue,
                        "uuid": context?.uuid ?? "",
                        "sId": context?.sessionId ?? 0
                    ]
                )

                return false
            }
            let listId = String(operandValue[range])
            // Process the tag value and prepare query parameters
            
            guard let tagValue = properties["_vwoUserId"] as? String else  {
                return false
            }
            let attributeValue = preProcessTagValue(tagValue)
            var result = false
            checkAttributeInList(listId: listId, attributeValue: attributeValue, userId: userId, featureKey: feature?.key ?? "", customVariable: false, context: context) { booleanValue in
                result = booleanValue
            }
            return result
        } else {
            let users = dslOperandValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "") }
            return users.contains(properties["_vwoUserId"] as? String ?? "")
        }
    }

    /// Evaluates a given string tag value against a DSL operand value.
    /// - Parameters:
    ///   - dslOperandValue: The DSL operand string (e.g., "contains(\"value\")").
    ///   - value: The tag value to evaluate.
    /// - Returns: `true` if tag value matches DSL operand criteria, `false` otherwise.
   static func evaluateStringOperandDSL(dslOperandValue: String, value: String) -> Bool {
       var tagValue = String(describing:value).trimmingCharacters(in: .whitespacesAndNewlines)
       tagValue = convertValue(tagValue)
        // Pre-process the DSL operand string to extract type and value.
        let preProcessedOperand = preProcessOperandValue(dslOperandValue)

        // Ensure OPERAND_VALUE exists and convert it.
        guard let operandRawValue = preProcessedOperand[OPERAND_VALUE] else {
            return false
        }

        var processedValues: [String: Any] = [:]
        processedValues[OPERAND_VALUE] = convertValue(operandRawValue!)

        // Extract the operand type (assuming it's castable to SegmentOperandValueEnum)
        let operandType = preProcessedOperand[OPERAND_TYPE] as? SegmentOperandValueEnum

        let cleanConvertedOperand = String(describing: processedValues[OPERAND_VALUE] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Evaluate and return result
        return extractResult(
             operandType,
             cleanConvertedOperand,
             tagValue
        )
    }

    
    /**
     * Evaluates a user agent DSL operand against the user's context.
     *
     * @param dslOperandValue The DSL operand value as a string.
     * @param context The user's context containing the user agent information.
     * @return `true` if the operand matches the user agent, `false` otherwise.
     */
    static func evaluateUserAgentDSL(_ dslOperandValue: String, _ context: VWOUserContext?) -> Bool {
        guard let userAgent = context?.userAgent else {
            LoggerService.errorLog(
                key: "INVALID_USER_AGENT_IN_CONTEXT_FOR_PRE_SEGMENTATION",
                data: [:],
                debugData: [
                    "an": ApiEnum.getFlag.rawValue,
                    "uuid": context?.uuid ?? "",
                    "sId": context?.sessionId ?? 0
                ]
            )
            return false
        }
        var tagValue = userAgent.removingPercentEncoding ?? ""
        
        let preProcessOperandValue = preProcessOperandValue(dslOperandValue)
        let processedValues = processValues(preProcessOperandValue[OPERAND_VALUE] as! String, tagValue)

        tagValue = processedValues[TAG_VALUE] as! String
        let operandType = preProcessOperandValue[OPERAND_TYPE] as? SegmentOperandValueEnum
        return extractResult(operandType, processedValues[OPERAND_VALUE] as! String, tagValue)
    }

    /**
     * Pre-processes the tag value by trimming whitespace and converting booleans to strings.
     *
     * @param tagValue The tag value to pre-process.
     * @return The pre-processed tag value.
     */
    
    static func preProcessTagValue(_ tagValue: String) -> String {
        if DataTypeUtil.isBoolean(tagValue) {
            return tagValue.lowercased()
        }
        return tagValue.trimmingCharacters(in: .whitespaces)
    }

    /**
     * Processes the operand and tag values by converting them to appropriate data types.
     *
     * @param operandValue The operand value to process.
     * @param tagValue The tag value to process.
     * @return A map containing the processed operand and tag values.
     */
    static private func processValues(_ operandValue: String, _ tagValue: String) -> [String: Any] {
        var result = [String: Any]()
        // Process operandValue
        result[OPERAND_VALUE] = convertValue(operandValue)

        // Process tagValue
        result[TAG_VALUE] = convertValue(tagValue)

        return result
    }

    /**
     * Converts a value to a string representation, handling booleans and numbers appropriately.
     *
     * @param value The value to convert.
     * @return The string representation of the value.
     */
    static private func convertValue(_ value: Any) -> String {
        if let boolValue = value as? Bool {
            return boolValue.description // Convert boolean to "true" or "false"
        }

        if let doubleValue = Double("\(value)") {
            // Check if the numeric value is actually an integer
            if doubleValue == Double(Int(doubleValue)) {
                return "\(Int(doubleValue))" // Remove '.0' by converting to int
            } else {
                // Format float to avoid scientific notation for large numbers
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 12 // Adjust the pattern as needed
                return formatter.string(from: NSNumber(value: doubleValue)) ?? "\(doubleValue)"
            }
        }

        return "\(value)"
    }

    /**
     * Compares two version strings using semantic versioning rules.
     * @param version1 The first version string.
     * @param version2 The second version string.
     * @return Comparison result: -1 if version1 < version2, 0 if equal, 1 if version1 > version2.
     */
    static func compareVersions(_ version1: String, _ version2: String) -> Int {
        let components1 = version1.split(separator: ".").compactMap { Int($0) }
        let components2 = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(components1.count, components2.count)
        
        for i in 0..<maxLength {
            let comp1 = i < components1.count ? components1[i] : 0
            let comp2 = i < components2.count ? components2[i] : 0
            
            if comp1 < comp2 {
                return -1
            } else if comp1 > comp2 {
                return 1
            }
        }
        
        return 0
    }
    
    /**
     * Checks if a string looks like a version number (contains dots).
     * @param value The string to check.
     * @return True if the string appears to be a version number.
     */
    static func isVersionString(_ value: String) -> Bool {
        return value.contains(".")
    }
    
    /**
     * Extracts the result of the evaluation based on the operand type and values.
     * @param operandType The type of the operand.
     * @param operandValue The value of the operand.
     * @param tagValue The value of the tag to compare against.
     * @return A boolean indicating the result of the evaluation.
     */
    static func extractResult(_ operandType: SegmentOperandValueEnum?, _ operandValue: String, _ tagValue: String) -> Bool {
        switch operandType {
        case .lowerValue:
            return operandValue.caseInsensitiveCompare(tagValue) == .orderedSame

        case .startingEndingStarValue:
            return tagValue.contains(operandValue)

        case .startingStarValue:
            return tagValue.hasSuffix(operandValue)

        case .endingStarValue:
            return tagValue.hasPrefix(operandValue)

        case .regexValue:
            do {
                let pattern = try NSRegularExpression(pattern: operandValue)
                let range = NSRange(location: 0, length: tagValue.utf16.count)
                return pattern.firstMatch(in: tagValue, options: [], range: range) != nil
            } catch {
                return false
            }

        case .greaterThanValue:
            // Check if both values look like version numbers
            if isVersionString(tagValue) && isVersionString(operandValue) {
                return compareVersions(tagValue, operandValue) > 0
            }
            // Fall back to numeric comparison for non-version strings
            if let tagFloat = Float(tagValue), let operandFloat = Float(operandValue) {
                return tagFloat > operandFloat
            }
            return false

        case .greaterThanEqualToValue:
            // Check if both values look like version numbers
            if isVersionString(tagValue) && isVersionString(operandValue) {
                return compareVersions(tagValue, operandValue) >= 0
            }
            // Fall back to numeric comparison for non-version strings
            if let tagFloat = Float(tagValue), let operandFloat = Float(operandValue) {
                return tagFloat >= operandFloat
            }
            return false

        case .lessThanValue:
            // Check if both values look like version numbers
            if isVersionString(tagValue) && isVersionString(operandValue) {
                return compareVersions(tagValue, operandValue) < 0
            }
            // Fall back to numeric comparison for non-version strings
            if let tagFloat = Float(tagValue), let operandFloat = Float(operandValue) {
                return tagFloat < operandFloat
            }
            return false

        case .lessThanEqualToValue:
            // Check if both values look like version numbers
            if isVersionString(tagValue) && isVersionString(operandValue) {
                return compareVersions(tagValue, operandValue) <= 0
            }
            // Fall back to numeric comparison for non-version strings
            if let tagFloat = Float(tagValue), let operandFloat = Float(operandValue) {
                return tagFloat <= operandFloat
            }
            return false

        default:
            return tagValue.lowercased() == operandValue.lowercased()
        }
    }

    /**
     * Extracts the operand value based on the provided regex pattern.
     *
     * @param operand The operand to be matched.
     * @param regex The regex pattern to match the operand against.
     * @return The extracted operand value or the original operand if no match is found.
     */
    static func extractOperandValue(_ operand: String, _ regex: String) -> String? {
        let pattern = try? NSRegularExpression(pattern: regex)
        let range = NSRange(location: 0, length: operand.utf16.count)
        let match = pattern?.firstMatch(in: operand, options: [], range: range)
        if let match = match, let range = Range(match.range(at: 1), in: operand) {
            return String(operand[range])
        }
        return operand
    }
    
    /**
      * Checks if a given attribute value is present in a specified list.
      *
      * This function first checks if the result is already cached in local storage.
      * If not, it makes a web service call to verify the attribute against the list.
      * The result is then cached for future use.
      *
      * @param listId The identifier of the list to check against.
      * @param attributeValue The attribute value to be checked.
      * @param userId The user identifier.
      * @param featureKey The key of the feature being evaluated.
      * @param customVariable A flag indicating if a custom variable is used.
      * @param completion A closure that is called with the result of the check.
      */
    static func checkAttributeInList(
        listId: String,
        attributeValue: String,
        userId: String,
        featureKey: String,
        customVariable: Bool,
        context: VWOUserContext?,
        completion: @escaping (Bool) -> Void
    ) {
        let storageService = StorageService()
        
        // Check if the result is already cached
        if let cacheResult = storageService.getAttributeCheck(featureKey: featureKey, listId: listId, attribute: attributeValue, userId: userId, customVariable: customVariable) {
            completion(cacheResult)
            return
        }
        
        var queryParamsObj = [String: String]()
        queryParamsObj["attribute"] = attributeValue
        queryParamsObj["listId"] = listId
        queryParamsObj["accountId"] = "\(SettingsManager.instance?.accountId ?? 0)"
        
        var result = false
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        // Make a web service call to check the attribute against the list
        GatewayServiceUtil.getFromGatewayService(queryParams: queryParamsObj, endpoint: UrlEnum.attributeCheck.rawValue, context: context) { gatewayResponse in
            if let modelData = gatewayResponse {
                if let stringValue = modelData.data {
                    if let booleanValue = stringValue.toBool {
                        storageService.saveAttributeCheck(featureKey: featureKey, listId: listId, attribute: attributeValue, result: booleanValue, userId: userId, customVariable: customVariable)
                        result = booleanValue
                    }
                }
            }
            dispatchGroup.leave()
        }
        
        // Wait for the API call to complete
        dispatchGroup.wait()
        completion(result)
    }
}

fileprivate extension String {
    func replacingOccurrences(of pattern: SegmentOperandRegexEnum, with replacement: String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern.rawValue, options: [])
        let range = NSRange(location: 0, length: self.count)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replacement)
    }
    
    var toBool: Bool? {
        switch self.lowercased() {
        case "true":
            return true
        case "false":
            return false
        default:
            return nil
        }
    }
    
}
