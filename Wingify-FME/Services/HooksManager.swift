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

public protocol IntegrationCallback {
    func execute(_ properties: [String: Any])
}

class HooksManager {
    private var callback: IntegrationCallback?
    private var decision: [String: Any]?
    // Integration callback should fire only once per unique evaluation payload.
    private var executedSignatures: Set<String> = []
    private let triggerEveryTime: Bool
    private let lock = NSLock()

    init(callback: IntegrationCallback?, triggerEveryTime: Bool = false) {
        self.callback = callback
        self.triggerEveryTime = triggerEveryTime
    }

    /**
     * Executes the callback
     *
     * @param properties Properties from the callback
     */
    func execute(properties: [String: Any]?) {
        guard let callback = self.callback, let properties = properties else {
            return
        }
        if triggerEveryTime {
            callback.execute(properties)
            return
        }
        let signature = makeSignature(from: properties)
        lock.lock()
        let shouldExecute = !executedSignatures.contains(signature)
        if shouldExecute {
            executedSignatures.insert(signature)
        }
        lock.unlock()
        if shouldExecute {
            callback.execute(properties)
        }
    }

    /**
     * Sets properties to the decision object
     *
     * @param properties Properties to set
     */
    func set(properties: [String: Any]?) {
        if self.callback != nil {
            self.decision = properties
        }
    }

    /**
     * Retrieves the decision object
     *
     * @return The decision object
     */
    func get() -> [String: Any]? {
        return self.decision
    }

    /// Builds a stable signature string for deduplicating integration callback payloads.
    private func makeSignature(from properties: [String: Any]) -> String {
        let normalized = normalizeForSignature(properties)
        guard JSONSerialization.isValidJSONObject(normalized),
              let data = try? JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return String(describing: normalized)
        }
        return json
    }

    /// Recursively normalizes Any values to JSON-compatible primitives/maps/arrays.
    private func normalizeForSignature(_ value: Any) -> Any {
        switch value {
        case let dict as [String: Any]:
            var normalized: [String: Any] = [:]
            for key in dict.keys.sorted() {
                if let child = dict[key] {
                    normalized[key] = normalizeForSignature(child)
                }
            }
            return normalized
        case let arr as [Any]:
            return arr.map { normalizeForSignature($0) }
        case let number as NSNumber:
            return number
        case let string as String:
            return string
        case let bool as Bool:
            return bool
        case let int as Int:
            return int
        case let int64 as Int64:
            return int64
        case let double as Double:
            return double
        case let float as Float:
            return float
        default:
            return String(describing: value)
        }
    }
}
