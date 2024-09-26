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
 * Represents a feature flag and its associated variables.
 *
 * This class encapsulates information about a feature flag, including its enabled status and a
 * list of variables with their values.
 */
public class GetFlag {
    private var isFlagEnabled: Bool = false
    private var variables: [Variable] = []
    
    /**
     * Sets the variables for the feature flag.
     *
     * - Parameter variables: The list of variables to associate with the feature flag.
     */
    func setVariables(_ variables: [Variable]) {
        self.variables = variables
    }
    
    var variablesValue: [Variable] {
        return variables
    }
    
    public func isEnabled() -> Bool {
        return isFlagEnabled
    }
    
    func setIsEnabled(isEnabled: Bool) {
        self.isFlagEnabled = isEnabled
    }
    
    /**
     * Retrieves the value of a specific variable by its key.
     *
     * - Parameters:
     *   - key: The key of the variable to retrieve.
     *   - defaultValue: The default value to return if the variable is not found or its value is nil.
     * - Returns: The value of the variable if found, otherwise the default value.
     */
    public func getVariable(key: String?, defaultValue: Any) -> Any {
        for variable in variablesValue {
            if variable.key == key {
                return variable.value?.toJSONCompatible() ?? defaultValue
            }
        }
        return defaultValue
    }
    
    /**
     * Retrieves the list of variables as an array of dictionaries.
     *
     * - Returns: The list of variables, where each variable is represented as a dictionary with keys "key", "value", "type", and "id".
     */
    public func getVariables() -> [[String: Any]] {
        return variablesValue.map { convertVariableModelToDict($0) }
    }
    
    /**
     * Converts a Variable object to a dictionary representation.
     *
     * - Parameter variableModel: The Variable object to convert.
     * - Returns: A dictionary representation of the Variable object.
     */
    private func convertVariableModelToDict(_ variableModel: Variable) -> [String: Any] {
        return [
            "key": variableModel.key ?? "",
            "value": variableModel.value?.toJSONCompatible() ?? "",
            "type": variableModel.type ?? "",
            "id": variableModel.id ?? 0
        ]
    }
}
