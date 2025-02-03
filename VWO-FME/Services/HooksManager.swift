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

public protocol IntegrationCallback {
    func execute(_ properties: [String: Any])
}

class HooksManager {
    private var callback: IntegrationCallback?
    private var decision: [String: Any]?

    init(callback: IntegrationCallback?) {
        self.callback = callback
    }

    /**
     * Executes the callback
     *
     * @param properties Properties from the callback
     */
    func execute(properties: [String: Any]?) {
        if let callback = self.callback, let properties = properties {
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
}
