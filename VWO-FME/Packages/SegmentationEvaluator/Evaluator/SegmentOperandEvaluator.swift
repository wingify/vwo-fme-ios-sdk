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

class SegmentOperandEvaluator {

    /**
     * Evaluates a custom variable DSL operand against user properties.
     *
     * @param dslOperandValue The DSL operand value as a dictionary.
     * @param properties The user properties to evaluate against.
     * @return `true` if the operand matches the user properties, `false` otherwise.
     */
    
    static func evaluateCustomVariableDSL(_ dslOperandValue: [String: CodableValue], _ properties: [String: Any]) -> Bool {
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
            let listIdPattern = try? NSRegularExpression(pattern: "inlist\\((\\w+:\\d+)\\)")
            let matches = listIdPattern?.matches(in: operandValue, options: [], range: NSRange(location: 0, length: operandValue.utf16.count))
            guard let match = matches?.first, let range = Range(match.range(at: 1), in: operandValue) else {
                LoggerService.log(level: .error, message: "Invalid 'inList' operand format")
                return false
            }
            let listId = String(operandValue[range])
            // Process the tag value and prepare query parameters
            let attributeValue = preProcessTagValue(tagValue as! String)
            var queryParamsObj = [String: String]()
            queryParamsObj["attribute"] = attributeValue
            queryParamsObj["listId"] = listId
            
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            // Make a web service call to check the attribute against the list
            GatewayServiceUtil.getFromGatewayService(queryParams: queryParamsObj, endpoint: UrlEnum.attributeCheck.rawValue) { gatewayResponse in

                if let modelData = gatewayResponse {
                    if let stringValue = modelData.data {
                        if let booleanValue = stringValue.toBool {
                            result = booleanValue
                        }
                    }
                }
                semaphore.signal() // Signal the semaphore to unblock the waiting thread
            }

            // Wait for the API call to complete
            semaphore.wait()
            return result
        } else {
            // Process other types of operands
            var tagValue = properties[operandKey] ?? ""
            tagValue = preProcessTagValue("\(tagValue)")
            let preProcessOperandValue = preProcessOperandValue(operandValue)
            var processedValues = processValues(preProcessOperandValue["operandValue"] as! String, tagValue as! String)

            
            // Convert numeric values to strings if processing wildcard pattern
            let operandType = preProcessOperandValue["operandType"] as? SegmentOperandValueEnum
            
            if operandType == .startingEndingStarValue || operandType == .startingStarValue || operandType == .endingStarValue || operandType == .regexValue {
                let valueForKey = String(describing: processedValues["tagValue"])
                processedValues["tagValue"] = valueForKey
            }
            tagValue = processedValues["tagValue"] as! String
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

        return ["operandType": operandType, "operandValue": operandValue]
    }

    /**
     * Evaluates a user DSL operand against user properties.
     *
     * @param dslOperandValue The DSL operand value as a string.
     * @param properties The user properties to evaluate against.
     * @return `true` if the operand matches the user properties, `false` otherwise.
     */
    static func evaluateUserDSL(_ dslOperandValue: String, _ properties: [String: Any]) -> Bool {
        let users = dslOperandValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "") }
        return users.contains(properties["_vwoUserId"] as? String ?? "")
    }

    /**
     * Evaluates a user agent DSL operand against the user's context.
     *
     * @param dslOperandValue The DSL operand value as a string.
     * @param context The user's context containing the user agent information.
     * @return `true` if the operand matches the user agent, `false` otherwise.
     */
    static func evaluateUserAgentDSL(_ dslOperandValue: String, _ context: VWOContext?) -> Bool {
        guard let userAgent = context?.userAgent else {
            LoggerService.log(level: .info, message: "To Evaluate UserAgent segmentation, please provide userAgent in context")
            return false
        }
        var tagValue = userAgent.removingPercentEncoding ?? ""
        
        let preProcessOperandValue = preProcessOperandValue(dslOperandValue)
        let processedValues = processValues(preProcessOperandValue["operandValue"] as! String, tagValue)

        tagValue = processedValues["tagValue"] as! String
        let operandType = preProcessOperandValue["operandType"] as? SegmentOperandValueEnum
        return extractResult(operandType, processedValues["operandValue"] as! String, tagValue)
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
        result["operandValue"] = convertValue(operandValue)

        // Process tagValue
        result["tagValue"] = convertValue(tagValue)

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
            return Float(tagValue) ?? 0 > Float(operandValue) ?? 0

        case .greaterThanEqualToValue:
            return Float(tagValue) ?? 0 >= Float(operandValue) ?? 0

        case .lessThanValue:
            return Float(tagValue) ?? 0 < Float(operandValue) ?? 0

        case .lessThanEqualToValue:
            return Float(tagValue) ?? 0 <= Float(operandValue) ?? 0

        default:
            return tagValue == operandValue
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
