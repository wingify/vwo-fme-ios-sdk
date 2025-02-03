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
    
    private init() {}
    
    /**
     * Creates an event with the given payload and saves it to Core Data.
     *
     * - Parameter payload: A dictionary containing event data.
     */
    func createEvent(payload: [String: Any]) {
        if payload.isEmpty { return }
        guard let payloadString = self.convertDictToString(payload) else {
            return
        }
        
        self.coreDataStack.context.perform {
            
            let settingManager = SettingsManager.instance
            let sdkKey = settingManager?.sdkKey ?? ""
            let accountId = Int64(settingManager?.accountId ?? 0)
            
            let eventData = EventData(context: self.coreDataStack.context)
            eventData.sdkKey = sdkKey
            eventData.accountId = accountId
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
     *   - completion: A closure that is called with a boolean indicating success or failure.
     */
    func uploadEvents(events: [EventData], completion: @escaping (Bool, [EventData]) -> Void) {
        let payloadData = events.compactMap({$0.payload})
        let payloadDataConverted = payloadData.compactMap({self.convertStringToDict($0)})
        let body = ["ev": payloadDataConverted]
        let settingManager = SettingsManager.instance
        let sdkKey = "\(settingManager?.sdkKey ?? "")"
        let headers = ["Authorization": sdkKey]
        let properties = NetworkUtil.getBatchEventsBaseProperties()
        let request = RequestModel(url: UrlService.baseUrl,
                                   method: HTTPMethod.post.rawValue,
                                   path: Constants.EVENT_BATCH_ENDPOINT,
                                   query: properties,
                                   body: body,
                                   headers: headers,
                                   scheme: Constants.HTTPS_PROTOCOL,
                                   port: settingManager?.port ?? 0)
        
        NetworkManager.attachClient()
        NetworkManager.postAsync(request) { result in
            if result.errorMessage != nil {
                LoggerService.log(level: .error, key: "BATCH_UPLOAD_ERROR", details: ["err": "\(result.errorMessage ?? "")"])
                completion(false, events)
            } else {
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
     */
    private func checkThreshold() {
        if SyncManager.shared.minimumEventCount == 0 && !SyncManager.shared.isOnlineBatchingAllowed { return }
        self.coreDataStack.countEntries { count, error in
            if error == nil {
                let eventCount = count ?? 0
                if eventCount >= SyncManager.shared.minimumEventCount && SyncManager.shared.minimumEventCount != 0 {
                    SyncManager.shared.syncSavedEvents()
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
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8)
            return jsonString
        } catch {
            return nil
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
