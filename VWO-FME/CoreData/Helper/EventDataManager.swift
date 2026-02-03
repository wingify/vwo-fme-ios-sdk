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
 * Manages event data operations including creation, uploading, and deletion.
 */
class EventDataManager {
    
    static let shared = EventDataManager()
    private let coreDataStack = CoreDataStack.shared
    
    // Store ServiceContainer references per account for multi-instance support
    // Key format: "accountId_sdkKey"
    private static var accountServiceContainers: [String: WeakServiceContainer] = [:]
    private static let containersQueue = DispatchQueue(label: "com.vwo.fme.eventdatamanager.containers", attributes: .concurrent)
    
    /**
     * Helper class to store weak references to ServiceContainer
     */
    private class WeakServiceContainer {
        weak var container: ServiceContainer?
        init(container: ServiceContainer) {
            self.container = container
        }
    }
    
    private init() {}
    
    /**
     * Registers a ServiceContainer for an account.
     * - Parameter serviceContainer: The ServiceContainer instance
     */
    static func registerServiceContainer(_ serviceContainer: ServiceContainer) {
        let accountKey = "\(serviceContainer.getAccountId())_\(serviceContainer.getSdkKey())"
        containersQueue.async(flags: .barrier) {
            accountServiceContainers[accountKey] = WeakServiceContainer(container: serviceContainer)
        }
    }
    
    /**
     * Gets the ServiceContainer for a specific account.
     * - Parameters:
     *   - accountId: The account ID
     *   - sdkKey: The SDK key
     * - Returns: The ServiceContainer if found, nil otherwise
     */
    static func getServiceContainer(accountId: Int, sdkKey: String) -> ServiceContainer? {
        let accountKey = "\(accountId)_\(sdkKey)"
        return containersQueue.sync {
            return accountServiceContainers[accountKey]?.container
        }
    }
    
    /**
     * Creates an event with the given payload and saves it to Core Data.
     *
     * - Parameter payload: A dictionary containing event data.
     * - Parameter sdkKey: Optional SDK key. If not provided, will try to extract from payload or use SettingsManager.
     * - Parameter accountId: Optional account ID. If not provided, will try to find from ServiceContainer registry using sdkKey.
     */
    func createEvent(payload: [String: Any], sdkKey: String? = nil, accountId: Int64? = nil) {
        if payload.isEmpty { return }
        guard let payloadString = self.convertDictToString(payload) else {
            return
        }
        
        self.coreDataStack.context.perform {
            // Try to get sdkKey from parameter, payload, or SettingsManager
            var eventSdkKey: String = sdkKey ?? ""
            if eventSdkKey.isEmpty {
                // Try to extract from payload (if it contains account info)
                if let accountInfo = payload["d"] as? [String: Any],
                   let sdkKeyFromPayload = accountInfo["sdkKey"] as? String {
                    eventSdkKey = sdkKeyFromPayload
                } else {
                    // Fallback to SettingsManager
                    eventSdkKey = SettingsManager.instance?.sdkKey ?? ""
                }
            }
            
            // Try to get accountId from parameter, ServiceContainer registry, or SettingsManager
            var eventAccountId: Int64 = accountId ?? 0
            if eventAccountId == 0 && !eventSdkKey.isEmpty {
                // Try to find ServiceContainer by sdkKey to get accountId
                var foundAccountId: Int64 = 0
                EventDataManager.containersQueue.sync {
                    for (_, weakContainer) in EventDataManager.accountServiceContainers {
                        if let container = weakContainer.container,
                           container.getSdkKey() == eventSdkKey {
                            foundAccountId = Int64(container.getAccountId())
                            break
                        }
                    }
                }
                eventAccountId = foundAccountId
            }
            
            // Final fallback to SettingsManager
            if eventAccountId == 0 {
                eventAccountId = Int64(SettingsManager.instance?.accountId ?? 0)
            }
            if eventSdkKey.isEmpty {
                eventSdkKey = SettingsManager.instance?.sdkKey ?? ""
            }
            
            
            let eventData = EventData(context: self.coreDataStack.context)
            eventData.sdkKey = eventSdkKey
            eventData.accountId = eventAccountId
            eventData.payload = payloadString
            
            self.coreDataStack.saveContext { done, error in
                if done {
                    self.checkThreshold()
                }
            }
        }
    }
    
    /**
     * Uploads a batch of events to the server.
     *
     * - Parameters:
     *   - events: An array of EventData objects to be uploaded.
     *   - serviceContainer: Optional ServiceContainer to use for account info and logging (for multi-instance support).
     *   - completion: A closure that is called with a boolean indicating success or failure.
     */
    func uploadEvents(events: [EventData], serviceContainer: ServiceContainer? = nil, completion: @escaping (Bool, [EventData]) -> Void) {
        let payloadData = events.compactMap({$0.payload})
        let payloadDataConverted = payloadData.compactMap({self.convertStringToDict($0)})
        let body = ["ev": payloadDataConverted]
        
        // Use ServiceContainer if provided, otherwise fallback to SettingsManager.instance
        let sdkKey: String
        let port: Int
        let loggerService: LoggerService?
        
        if let container = serviceContainer {
            sdkKey = container.getSdkKey()
            port = container.getSettingsManager()?.port ?? 0
            loggerService = container.getLoggerService()
        } else {
            // Fallback to SettingsManager for backward compatibility
            let settingManager = SettingsManager.instance
            sdkKey = settingManager?.sdkKey ?? ""
            port = settingManager?.port ?? 0
            
            // Extract account info from the first event to determine which instance logger to use
            if let firstEvent = events.first {
                let accountId = Int(firstEvent.accountId)
                let eventSdkKey = firstEvent.sdkKey ?? ""
                loggerService = LoggerService.getInstance(accountId: accountId, sdkKey: eventSdkKey)
            } else {
                loggerService = nil
            }
        }
        
        let headers = ["Authorization": sdkKey]
        let properties = NetworkUtil.getBatchEventsBaseProperties()
        // Get instance-specific base URL
        let baseUrl = UrlService.getBaseUrl(serviceContainer: serviceContainer)
        // Get accountId for the request
        let accountId = serviceContainer?.getAccountId()
        
        var request = RequestModel(url: baseUrl,
                                   method: HTTPMethod.post.rawValue,
                                   path: Constants.EVENT_BATCH_ENDPOINT,
                                   query: properties,
                                   body: body,
                                   headers: headers,
                                   scheme: Constants.HTTPS_PROTOCOL,
                                   port: port)
        // Set account info in request for multi-instance support
        request.accountId = accountId
        request.sdkKey = sdkKey
        
        NetworkManager.attachClient()
        NetworkManager.postAsync(request) { result in
            if result.errorMessage != nil {
                if let logger = loggerService {
                    logger.log(level: .debug, key: "BATCH_UPLOAD_ERROR", details: ["err": "\(result.errorMessage ?? "")"])
                } else {
                    // Fallback to static log if instance not found
                    LoggerService.log(level: .debug, key: "BATCH_UPLOAD_ERROR", details: ["err": "\(result.errorMessage ?? "")"])
                }
                completion(false, events)
            } else {
                UsageStatsUtil.shared.saveUsageStatsInStorage()
                completion(true, events)
            }
        }
    }
    
    /**
     * Deletes a batch of events from Core Data.
     *
     * - Parameters:
     *   - data: An array of EventData objects to be deleted.
     *   - completion: A closure that is called with a boolean indicating success or failure.
     */
    func deleteEvents(data: [EventData], completion: @escaping (Bool) -> Void) {
        self.coreDataStack.delete(events: data) { error in
            let done = error == nil
            completion(done)
        }
    }
    
    /**
     * Checks if the number of stored events has reached the threshold for uploading.
     * Uses instance-specific SyncManager if available, otherwise falls back to shared.
     */
    private func checkThreshold() {
        // Try to get the ServiceContainer for the current account
        let serviceContainer: ServiceContainer?
        if let settingsManager = SettingsManager.instance {
            serviceContainer = EventDataManager.getServiceContainer(accountId: settingsManager.accountId, sdkKey: settingsManager.sdkKey)
        } else {
            serviceContainer = nil
        }
        
        // Use instance-specific SyncManager if available, otherwise use shared
        let syncManager: SyncManager
        if let container = serviceContainer {
            syncManager = container.getSyncManager()
        } else {
            syncManager = SyncManager.shared
        }
        
        if syncManager.minimumEventCount == 0 && !syncManager.isOnlineBatchingAllowed { return }
        
        // Count entries for this specific account if we have ServiceContainer
        let accountId = serviceContainer?.getAccountId() ?? 0
        let sdkKey = serviceContainer?.getSdkKey() ?? ""
        
        if accountId > 0 && !sdkKey.isEmpty {
            // Count entries for this specific account
            self.coreDataStack.countEntries(accountId: Int64(accountId), sdkKey: sdkKey) { count, error in
                if error == nil {
                    let eventCount = count ?? 0
                    if eventCount >= syncManager.minimumEventCount && syncManager.minimumEventCount != 0 {
                        syncManager.syncSavedEvents()
                    }
                }
            }
        } else {
            // Fallback to counting all entries
            self.coreDataStack.countEntries { count, error in
                if error == nil {
                    let eventCount = count ?? 0
                    if eventCount >= syncManager.minimumEventCount && syncManager.minimumEventCount != 0 {
                        syncManager.syncSavedEvents()
                    }
                }
            }
        }
    }
    
    /**
     * Converts a dictionary to a JSON string.
     *
     * - Parameter payload: A dictionary to be converted.
     * - Returns: A JSON string representation of the dictionary, or nil if conversion fails.
     */
    private func convertDictToString(_ payload: [String: Any]) -> String? {
        do {
            let sanitizedPayload = sanitizeForJSON(payload)
            let jsonData = try JSONSerialization.data(withJSONObject: sanitizedPayload, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8)
            return jsonString
        } catch {
            return nil
        }
    }
    
    /// Recursively sanitizes a given object to ensure it can be safely serialized to JSON.
    ///
    /// This function walks through dictionaries and arrays, and ensures all values are JSON-compatible.
    /// If it encounters types like `Error`, custom enums, or other unsupported types, it converts them
    /// into a `String` representation (typically using `localizedDescription` or `String(describing:)`).
    ///
    /// - Parameter object: The object to sanitize. Can be a dictionary, array, or any other type.
    /// - Returns: A sanitized version of the object, safe for use with `JSONSerialization`.

    private func sanitizeForJSON(_ object: Any) -> Any {
        if let dict = object as? [String: Any] {
            var sanitized = [String: Any]()
            for (key, value) in dict {
                sanitized[key] = sanitizeForJSON(value)
            }
            return sanitized
        } else if let array = object as? [Any] {
            return array.map { sanitizeForJSON($0) }
        } else if let error = object as? Error {
            return error.localizedDescription // Or "\(error)"
        } else if JSONSerialization.isValidJSONObject([ "key": object ]) {
            return object
        } else {
            return "\(object)" // Fallback to string representation
        }
    }

    
    /**
     * Converts a JSON string to a dictionary.
     *
     * - Parameter payload: A JSON string to be converted.
     * - Returns: A dictionary representation of the JSON string, or nil if conversion fails.
     */
    private func convertStringToDict(_ payload: String) -> [String: Any]? {
        if payload.isEmpty { return nil }
        guard let jsonData = payload.data(using: .utf8) else {
            return nil
        }
        
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                return jsonObject
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
}
