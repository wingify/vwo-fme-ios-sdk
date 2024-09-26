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
 * Manages data storage and retrieval through a connector.
 *
 * This class provides a singleton instance for accessing and managing data storage operations. It
 * allows attaching a connector to interact with a specific data store and provides methods for
 * setting and retrieving data.
 */

class StorageOps {
    private var connector: Connector?

    // Private initializer to prevent the creation of additional instances
    private init() {}

    /**
     * Attaches a connector to the storage instance.
     *
     * @param connectorInstance The connector instance to attach.
     * @return The attached connector instance.
     */
    func attachConnector(connectorInstance: Connector?) -> Connector? {
        self.connector = connectorInstance
        return self.connector
    }

    /**
     * Retrieves the attached connector instance.
     *
     * @return The attached connector instance or nil if no connector is attached.
     */
    func getConnector() -> Connector? {
        return self.connector
    }

    // Static property to hold the single instance of StorageOps
    static let shared: StorageOps = {
        let instance = StorageOps()
        return instance
    }()
}
