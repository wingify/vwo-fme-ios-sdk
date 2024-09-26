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
 * An abstract class representing a connector for data storage and retrieval.
 *
 * This class defines the basic interface for connectors that interact with data storage mechanisms.
 * Subclasses must implement the `set` and `get` methods to provide concrete implementations for
 * specific data stores.
 */

protocol ConnectorProtocol {
    func get(featureKey: String?, userId: String?) throws -> [String: Any]
    func set(data: [String: Any]) throws
}

//TODO: Port this connector class later
class Connector {
    /**
     * Sets data for a given key.
     *
     * @param data A dictionary containing the data to be set.
     * @throws Error if an error occurs during the set operation.
     */
    func set(data: [String: Any]) throws {
        fatalError("This method must be overridden")
    }

    /**
     * Retrieves data for a given feature key and user ID.
     *
     * @param featureKey The key of the feature for which to retrieve data.
     * @param userId The ID of the user for which to retrieve data.
     * @return The retrieved data or nil if no data is found.
     * @throws Error if an error occurs during the get operation.
     */
    func get(featureKey: String?, userId: String?) throws -> [String: Any] {
        fatalError("This method must be overridden")
    }
}

