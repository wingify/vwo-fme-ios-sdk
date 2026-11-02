/**
 * Copyright 2024-2026 Wingify Software Pvt. Ltd.
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
@objc public class GetFlag: NSObject {
    private var isFlagEnabled: Bool = false
    private var variables: [Variable] = []

    private var impressionAlreadySent = false
    private var pendingImpressions = ImpressionPayload()
    private var exposeDeps: ImpressionExposureHelper.ExposeDeps?

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

    /**
     * Returns whether this feature flag is enabled for the user.
     */
    @objc public func isEnabled() -> Bool {
        return isFlagEnabled
    }

    func setIsEnabled(isEnabled: Bool) {
        self.isFlagEnabled = isEnabled
    }

    /**
     * Retrieves the value of a specific variable by its key.
     */
    @objc public func getVariable(key: String?, defaultValue: Any) -> Any {
        for variable in variablesValue {
            if variable.key == key {
                return variable.value?.toJSONCompatible() ?? defaultValue
            }
        }
        return defaultValue
    }

    /**
     * Retrieves the list of variables as an array of dictionaries.
     */
    @objc public func getVariables() -> [[String: Any]] {
        return variablesValue.map { convertVariableModelToDict($0) }
    }

    /**
     * Sends a previously deferred `vwo_variationShown` impression for this flag result.
     * Use after `fetchFlags` / `getFlags(shouldSendTrackingCalls: false)`.
     * Idempotent — safe to call multiple times.
     *
     * - Returns: `true` when an impression was sent; `false` when there was nothing to send
     *   or it had already been sent.
     */
    @objc public func exposeResult() -> Bool {
        return ImpressionExposureHelper.expose(getFlag: self)
    }

    // MARK: - Impression defer / expose (internal)

    /**
     * Attaches evaluation dependencies needed later by `exposeResult`.
     */
    func attachExposeDeps(_ deps: ImpressionExposureHelper.ExposeDeps) {
        exposeDeps = deps
    }

    /**
     * Returns the expose dependencies attached during evaluation, if any.
     */
    func getExposeDeps() -> ImpressionExposureHelper.ExposeDeps? {
        exposeDeps
    }

    /**
     * Merges deferred variation-shown rows into this flag's in-memory stash.
     */
    func mergePendingImpressions(_ payload: ImpressionPayload) {
        pendingImpressions.merge(payload)
    }

    /**
     * Returns and clears the in-memory deferred impression stash.
     */
    func consumePendingImpressions() -> ImpressionPayload {
        let copy = ImpressionPayload()
        copy.merge(pendingImpressions)
        pendingImpressions.clear()
        return copy
    }

    /**
     * Marks this flag result as having already sent its variation-shown impression.
     */
    func markImpressionSent() {
        impressionAlreadySent = true
    }

    /**
     * Returns whether this flag result has already sent its variation-shown impression.
     */
    func isImpressionAlreadySent() -> Bool {
        impressionAlreadySent
    }

    private func convertVariableModelToDict(_ variableModel: Variable) -> [String: Any] {
        return [
            "key": variableModel.key ?? "",
            "value": variableModel.value?.toJSONCompatible() ?? "",
            "type": variableModel.type ?? "",
            "id": variableModel.id ?? 0
        ]
    }
}
