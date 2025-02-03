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
 * Utility class for segment operations.
 */
class SegmentUtil {
    /**
     * Checks if the actual values match the expected values specified in the map.
     * @param expectedMap A map of expected values for different keys.
     * @param actualMap A map of actual values to compare against.
     * @return A boolean indicating if all actual values match the expected values.
     */
    static func checkValuePresent(expectedMap: [String: [String]], actualMap: [String: String]) -> Bool {
        for key in actualMap.keys {
            if let expectedValues = expectedMap[key] {
                // convert expectedValues to lowercase
                let lowercasedExpectedValues = expectedValues.map { $0.lowercased() }
                if let actualValue = actualMap[key] {
                    // Handle wildcard patterns for all keys
                    for val in lowercasedExpectedValues {
                        if val.hasPrefix("wildcard(") && val.hasSuffix(")") {
                            let wildcardPattern = String(val.dropFirst(9).dropLast(1)) // Extract pattern from wildcard string
                            let regexPattern = wildcardPattern.replacingOccurrences(of: "*", with: ".*")
                            if let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) {
                                let range = NSRange(location: 0, length: actualValue.utf16.count)
                                if regex.firstMatch(in: actualValue, options: [], range: range) != nil {
                                    return true // Match found, return true
                                }
                            }
                        }
                    }

                    // Direct value check for all keys
                    if lowercasedExpectedValues.contains(actualValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
                        return true // Direct value match found, return true
                    }
                }
            }
        }
        return false // No matches found
    }

    /**
     * Compares expected location values with user's location to determine a match.
     * @param expectedLocationMap A map of expected location values.
     * @param userLocation The user's actual location.
     * @return A boolean indicating if the user's location matches the expected values.
     */
    static func valuesMatch(expectedLocationMap: [String: CodableValue], userLocation: [String: String]) -> Bool {
        for (key, value) in expectedLocationMap {
            if let userLocationValue = userLocation[key] {
                let normalizedValue1 = normalizeValue(value)
                let normalizedValue2 = userLocationValue
                if normalizedValue1 != normalizedValue2 {
                    return false
                }
            } else {
                return false
            }
        }
        return true // If all values match, return true
    }

    /**
     * Normalizes a value to a consistent format for comparison.
     * @param value The value to normalize.
     * @return The normalized value.
     */
    
    static func normalizeValue(_ value: CodableValue?) -> String? {
        guard let value = value else {
            return nil
        }
        
        // Remove quotes and trim whitespace
        if let stringValue = value.stringValue {
            return stringValue.replacingOccurrences(of: "^\"|\"$", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    /**
     * Helper method to extract the first key-value pair from a map.
     */
    
    static func getKeyValue(_ node: [String: CodableValue]) -> (key: String, value: CodableValue)? {
        return node.first
    }

    /**
     * Matches a string against a regular expression and returns the match result.
     * @param string - The string to match against the regex.
     * @param regex - The regex pattern as a string.
     * @return The results of the regex match, or null if an error occurs.
     */
    static func matchWithRegex(string: String?, regex: String?) -> Bool {
        guard let string = string, let regex = regex else {
            return false
        }
        do {
            let pattern = try NSRegularExpression(pattern: regex)
            let range = NSRange(location: 0, length: string.utf16.count)
            return pattern.firstMatch(in: string, options: [], range: range) != nil
        } catch {
            // Return false if an error occurs during regex matching
            return false
        }
    }
}
