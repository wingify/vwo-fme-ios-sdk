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
 * Provides data storage and retrieval services.
 *
 * This class is responsible for managing the storage and retrieval of data used by the application,
 * such as user preferences, application state, or other persistent information.
 */
class StorageService {
    
    /**
     * Retrieves data from storage based on the feature key and user ID.
     * @param featureKey The key to identify the feature data.
     * @param context The context model containing at least an ID.
     * @return The data retrieved or an error/storage status enum.
     */
    func getDataInStorage(featureKey: String?, context: VWOContext) -> [String: Any]? {
        
        guard let storageInstance = StorageOps.shared.getConnector() else { return nil }
        
        do {
            return try storageInstance.get(featureKey: featureKey, userId: context.id)
        } catch {
            LoggerService.log(level: .error, key: "STORED_DATA_ERROR", details: ["err": "\(error)"])
            return nil
        }
    }
    
    /**
     * Stores data in the storage.
     * @param data The data to be stored as a map.
     * @return true if data is successfully stored, otherwise false.
     */
    func setDataInStorage(data: [String: Any]) -> Bool {
        
        guard let storageInstance = StorageOps.shared.getConnector() else { return false }
        
        do {
            try storageInstance.set(data: data)
            return true
        } catch {
            LoggerService.log(level: .error, key: "STORED_DATA_ERROR", details: ["err": "\(error)"])
            return false
        }
        
    }
}
