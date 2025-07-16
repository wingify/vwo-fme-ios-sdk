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
 * A protocol that defines the interface for custom storage connectors in the VWO FME SDK.
 *
 * This protocol allows developers to implement custom storage solutions for the VWO SDK,
 * enabling integration with various storage backends such as databases, cloud storage,
 * or custom key-value stores.
 *
 * ## Usage
 * ```swift
 * class MyCustomStorage: VWOStorageConnector {
 *     func set(_ value: Any?, forKey key: String) {
 *         // Store value in your custom storage
 *         myStorage.setValue(value, forKey: key)
 *     }
 *     
 *     func get(forKey key: String) -> [String:Any]? {
 *         // Retrieve value from your custom storage
 *         return myStorage.getValue(forKey: key) as? [String:Any]
 *     }
 * }
 * ```
 *
 * ## Requirements
 * - Implement `set(_:forKey:)` to store data
 * - Implement `get(forKey:)` to retrieve data
 * - Both methods should be thread-safe for concurrent access
 * - The `get` method should return `nil` if the key doesn't exist
 */
public protocol VWOStorageConnector {
    func set(_ value: Any?, forKey key: String)
    func get(forKey key: String) -> [String:Any]?
}
