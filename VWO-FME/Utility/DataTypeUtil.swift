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
 * Utility class for data type operations.
 *
 * This class provides helper methods for checking and determining the type of various data values. It offers functions to identify objects, arrays, null values, undefined values, numbers, strings, booleans, dates, functions, and more.
 */
class DataTypeUtil {
    
    /**
     * Checks if a value is an object.
     *
     * - Parameter val: The value to check.
     * - Returns: `true` if the value is an object, `false` otherwise.
     */
    static func isObject(_ val: Any?) -> Bool {
        guard let val = val else { return false }
        return !(val is Array<Any>) && !(val is String) && !(val is Date) && type(of: val) is AnyClass
    }
    
    /**
     * Checks if a value is an array.
     *
     * - Parameter val: The value to check.
     * - Returns: `true` if the value is an array, `false` otherwise.
     */
    static func isArray(_ val: Any?) -> Bool {
        return val is Array<Any>
    }
    
    /**
     * Checks if a value is a dictionary.
     *
     * - Parameter val: The value to check.
     * - Returns: `true` if the value is a dictionary, `false` otherwise.
     */
    static func isDictionary(_ val: Any?) -> Bool {
        return val is [AnyHashable: Any]
    }
    
    /**
     * Checks if a value is null.
     *
     * - Parameter val: The value to check.
     * - Returns: `true` if the value is null, `false` otherwise.
     */
    static func isNull(_ val: Any?) -> Bool {
        return val == nil
    }
    
    /**
     * Checks if a value is undefined.
     *
     * - Parameter val: The value to check.
     * - Returns: `true` if the value is undefined, `false` otherwise.
     */
    static func isUndefined(_ val: Any?) -> Bool {
        return val == nil
    }
    
    /**
     * Checks if a value is defined.
     *
     * - Parameter val: The value to check.
     * - Returns: `true` if the value is defined, `false` otherwise.
     */
    static func isDefined(_ val: Any?) -> Bool {
        return val != nil
    }
    
    /**
     * Checks if a value is a number.
     *
     * - Parameter val: The value to check.
     * - Returns: `true` if the value is a number, `false` otherwise.
     */
    static func isNumber(_ val: Any?) -> Bool {
        return val is NSNumber
    }
    
    /**
     * Checks if a value is an integer.
     *
     * - Parameter val: The value to check.
     * - Returns: `true` if the value is an integer, `false` otherwise.
     */
    static func isInteger(_ val: Any?) -> Bool {
        return val is Int
    }
    
    /**
     * Checks if a value is a string.
     *
     * - Parameter val: The value to check.
     * - Returns: `true` if the value is a string, `false` otherwise.
     */
    static func isString(_ val: Any?) -> Bool {
        return val is String
    }
    
    /**
     * Checks if a value is a boolean.
     *
     * - Parameter val: The value to check.
     * - Returns: `true` if the value is a boolean, `false` otherwise.
     */
    static func isBoolean(_ val: Any?) -> Bool {
        return val is Bool
    }
    
    /**
     * Checks if a value is NaN (Not a Number).
     *
     * - Parameter val: The value to check.
     * - Returns: `true` if the value is NaN, `false` otherwise.
     */
    static func isNaN(_ val: Any?) -> Bool {
        guard let doubleVal = val as? Double else { return false }
        return doubleVal.isNaN
    }
    
    /**
     * Checks if a value is a date.
     *
     * - Parameter val: The value to check.
     * - Returns: `true` if the value is a date, `false` otherwise.
     */
    static func isDate(_ val: Any?) -> Bool {
        return val is Date
    }
    
    /**
     * Gets the type of a value as a string.
     *
     * - Parameter val: The value to check.
     * - Returns: The type of the value as a string.
     */
    static func getType(_ val: Any?) -> String {
        switch val {
        case _ where isObject(val):
            return "Object"
        case _ where isArray(val):
            return "Array"
        case _ where isNull(val):
            return "Null"
        case _ where isUndefined(val):
            return "Undefined"
        case _ where isNaN(val):
            return "NaN"
        case _ where isNumber(val):
            return "Number"
        case _ where isString(val):
            return "String"
        case _ where isBoolean(val):
            return "Boolean"
        case _ where isDate(val):
            return "Date"
        case _ where isInteger(val):
            return "Integer"
        case _ where isDictionary(val):
                return "Dictionary"
        default:
            return "Unknown Type"
        }
    }
    
    /**
     * Filters a dictionary to include only string key-value pairs.
     *
     * - Parameter originalDict: The original dictionary to filter.
     * - Returns: A new dictionary containing only string key-value pairs.
     */
    static func filterStringDictionary(_ originalDict: [AnyHashable: Any]) -> [String: String] {
        
        var cleanedDict: [String: String] = [:]
        
        for (key, value) in originalDict {
            if let stringKey = key as? String,
               let stringValue = value as? String {
                cleanedDict[stringKey] = stringValue
            } else if let stringKey = key as? String,
                      let nestedDict = value as? [AnyHashable: Any] {
                // Recursively filter nested dictionaries
                
                let cleanedNestedDict = filterStringDictionary(nestedDict)
                for (nestedKey, nestedValue) in cleanedNestedDict {
                    cleanedDict["\(stringKey).\(nestedKey)"] = nestedValue
                }
            }
        }
        
        return cleanedDict
    }
    
    
}
