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
 * A service for managing local storage using UserDefaults.
 *
 * This class provides methods to save, load, and clear settings, version information,
 * and other data related to the application's local storage.
 */
class StorageService {
   
    private let userDefaults: UserDefaults
    
    private struct Keys {
        static let settings = "com.vwo.fme.settings"
        static let version = "com.vwo.fme.version"
        static let settingExpiry = "com.vwo.fme.settingExpiry"
    }
        
    /**
     * Initializes a new instance of StorageService.
     *
     * This initializer attempts to create a UserDefaults instance with a specific suite name.
     * If it fails, the application will terminate with a fatal error.
     */
    init() {
        if let defaults = UserDefaults(suiteName: Constants.SDK_USERDEFAULT_SUITE) {
            self.userDefaults = defaults
        } else {
            fatalError("Unable to initialize UserDefaults with suite")
        }
    }
    
    /**
     * Saves the provided settings to local storage.
     *
     * - Parameter settings: The settings object to be saved.
     */
    func saveSettings(_ settings: Settings) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: Keys.settings)
        } catch {
            LoggerService.log(level: .error, key: "SETTINGS_SCHEMA_INVALID", details: [:])
        }
    }
    
    /**
     * Loads the settings from local storage.
     *
     * - Returns: The settings object if available, otherwise nil.
     */
    func loadSettings() -> Settings? {
        if let data = userDefaults.data(forKey: Keys.settings) {
            let decoder = JSONDecoder()
            do {
                let settings = try decoder.decode(Settings.self, from: data)
                return settings
            } catch {
                LoggerService.log(level: .error, key: "SETTINGS_SCHEMA_INVALID", details: [:])
            }
        }
        return nil
    }
    
    /**
     * Clears the settings from local storage.
     */
    func clearSettings() {
        userDefaults.removeObject(forKey: Keys.settings)
    }
    
    /**
     * Retrieves the setting expiry time from local storage.
     *
     * - Returns: The expiry time as an Int64 if available, otherwise nil.
     */
    func getSettingExpiry() -> Int64? {
        
        let data = userDefaults.value(forKey: Keys.settingExpiry)
        if let expiryTime = data as? Int64 {
            return expiryTime
        }
        return nil
    }
    
    /**
     * Saves the setting expiry time to local storage.
     *
     * - Parameter timeInterval: The expiry time to be saved.
     */
    func saveSettingExpiry(timeInterval: Int64) {
        userDefaults.set(timeInterval, forKey: Keys.settingExpiry)
    }
    
    /**
     * Clears the setting expiry time from local storage.
     */
    func clearSettingExpiry() {
        userDefaults.removeObject(forKey: Keys.settingExpiry)
    }
    
    /**
     * Saves the version information to local storage.
     *
     * - Parameter version: The version string to be saved.
     */
    func saveVersion(_ version: String) {
        userDefaults.set(version, forKey: Keys.version)
    }
    
    /**
     * Loads the version information from local storage.
     *
     * - Returns: The version string if available, otherwise nil.
     */
    func loadVersion() -> String? {
        return userDefaults.string(forKey: Keys.version)
    }
    
    /**
     * Empties the local storage suite.
     */
    func emptyLocalStorageSuite() {
        userDefaults.removeSuite(named: Constants.SDK_USERDEFAULT_SUITE)
    }
        
    /**
     * Retrieves data from storage for a specific feature key and context.
     *
     * - Parameters:
     *   - featureKey: The key for the feature.
     *   - context: The context containing user information.
     * - Returns: A dictionary of stored data if available, otherwise nil.
     */
    private func getDataInStorage(featureKey: String?, context: VWOContext) -> [String: Any]? {
        guard let featureKey = featureKey else { return nil }
        guard let userId = context.id else { return nil }
        
        let storageKey = "\(featureKey)_\(userId)"
        if let data = userDefaults.dictionary(forKey: storageKey) {
            return data
        } else {
            return nil
        }
    }
    
    /**
     * Sets data in storage for a specific feature key and user ID.
     *
     * - Parameter data: A dictionary containing the data to be stored.
     */
    func setDataInStorage(data: [String: Any]) {
        guard let featureKey = data["featureKey"] as? String, let userId = data["userId"] as? String else {
            LoggerService.log(level: .error, key: "STORING_DATA_ERROR", details: ["err": "Invalid data"])
            return
        }
        
        let rolloutKey = data["rolloutKey"] as? String
        let experimentKey = data["experimentKey"] as? String
        let rolloutVariationId = data["rolloutVariationId"] as? Int
        let experimentVariationId = data["experimentVariationId"] as? Int
        
        if let rolloutKey = rolloutKey, !rolloutKey.isEmpty, experimentKey == nil, rolloutVariationId == nil {
            LoggerService.log(level: .error, key: "STORING_DATA_ERROR", details: ["key": "Variation:(rolloutKey, experimentKey or rolloutVariationId)"])
            return
        }
        
        if let experimentKey = experimentKey, !experimentKey.isEmpty, experimentVariationId == nil {
            LoggerService.log(level: .error, key: "STORING_DATA_ERROR", details: ["key": "Variation:(experimentKey or rolloutVariationId)"])
            return
        }
        
        let storageKey = "\(featureKey)_\(userId)"
        userDefaults.set(data, forKey: storageKey)
    }
       
    /**
     * Retrieves a feature from storage for a specific feature key and context.
     *
     * - Parameters:
     *   - featureKey: The key for the feature.
     *   - context: The context containing user information.
     * - Returns: A dictionary of stored data if available, otherwise nil.
     */
    func getFeatureFromStorage(featureKey: String, context: VWOContext) -> [String : Any]? {
        return self.getDataInStorage(featureKey: featureKey, context: context)
    }
    
}
