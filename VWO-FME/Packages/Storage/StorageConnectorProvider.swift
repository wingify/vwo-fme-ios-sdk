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


/**
 * A singleton provider class that manages storage connector configuration for the VWO FME SDK.
 *
 * This class provides a centralized way to configure and access storage connectors throughout the SDK.
 * It supports both custom storage connectors and default UserDefaults storage.
 *
 * ## Usage
 * ```swift
 * // Configure with a custom storage connector
 * let customConnector = CustomStorageConnector()
 * StorageConnectorProvider.configure(with: customConnector)
 *
 * // Access the storage connector
 * let connector = StorageConnectorProvider.shared.getStorageConnector()
 * ```
 *
 * ## Features
 * - Singleton pattern for global access
 * - Support for custom storage connectors
 * - Fallback to default UserDefaults when no custom connector is provided
 * - Thread-safe configuration
 */
class StorageConnectorProvider{
    
    static var shared = StorageConnectorProvider()
    
    private let storageConnector: VWOStorageConnector?
    
    /**
     * Private initializer for the StorageConnectorProvider
     *
     * - Parameter storageConnector: An optional custom storage connector. If nil, the SDK will use UserDefaults as the default storage.
     */
    private init(storageConnector: VWOStorageConnector? = nil){
        self.storageConnector = storageConnector
    }
    
    /**
     * Configures the StorageConnectorProvider with a custom storage connector
     *
     * This method should be called before initializing the VWO SDK to ensure the custom storage connector
     * is used throughout the SDK lifecycle.
     *
     * - Parameter storageConnector: The custom storage connector to use. Pass nil to use the default UserDefaults storage.
     *
     * ## Example
     * ```swift
     * // Configure with custom storage
     * let customStorage = MyCustomStorageConnector()
     * StorageConnectorProvider.configure(with: customStorage)
     *
     * // Configure with default storage (UserDefaults)
     * StorageConnectorProvider.configure(with: nil)
     * ```
     */
    static func configure(with storageConnector: VWOStorageConnector?) {
        shared = StorageConnectorProvider(storageConnector: storageConnector)
        if storageConnector != nil {
            print("StorageService configured with a custom storage connector.")
        } else {
            print("StorageService configured with default UserDefaults.")
        }
    }
    
    /**
     * Retrieves the currently configured storage connector
     *
     * - Returns: The configured storage connector, or nil if using default UserDefaults storage
     *
     * ## Example
     * ```swift
     * let connector = StorageConnectorProvider.shared.getStorageConnector()
     * if let connector = connector {
     *     // Use custom storage connector
     *     connector.setValue("value", forKey: "key")
     * } else {
     *     // Using default UserDefaults storage
     *     UserDefaults.standard.set("value", forKey: "key")
     * }
     * ```
     */
    func getStorageConnector() -> VWOStorageConnector? {
        return storageConnector
    }
}
