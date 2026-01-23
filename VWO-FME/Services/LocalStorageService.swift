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
#if canImport(UIKit)
import UIKit
#endif

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
        static let userDetail = "com.vwo.fme.userDetail"
        static let userDetailExpiry = "com.vwo.fme.userDetailExpiry"
        static let attributeCheckExpiry = "com.vwo.fme.attributeCheckExpiry"
        static let usageStats = "com.vwo.fme.usageStats"
        static let aliasID = "com.vwo.fme.aliasID"
        static let aliasMappings = "com.vwo.fme.aliasMappings"
        static let deviceIdKey = "com.vwo.fme.deviceIdKey"

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
     * Saves the Alias Mappings Array to local storage.
     *
     * - Parameter aliasMappings: Array of alias mappings to be saved.
     */
    func setAliasMappings(aliasMappings: [[String: String]]) {
        userDefaults.set(aliasMappings, forKey: Keys.aliasMappings)
    }

    /**
     * Retrieves the Alias Mappings Array from local storage.
     *
     * - Returns: Array of alias mappings if available, otherwise nil.
     */
    func getAliasMappings() -> [[String: String]]? {
        if let existingMappings = userDefaults.array(forKey: Keys.aliasMappings) as? [[String: String]] {
            return existingMappings
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
     * Retrieves the user detail expiry time from local storage.
     *
     * - Returns: The expiry time as an Int64 if available, otherwise nil.
     */
    func getUserDetailExpiry() -> Int64? {
        let data = userDefaults.value(forKey: Keys.userDetailExpiry)
        if let expiryTime = data as? Int64 {
            return expiryTime
        }
        return nil
    }

    /**
     * Saves the user detail expiry time to local storage.
     *
     * - Parameter timeInterval: The expiry time to be saved.
     */
    func saveUserDetailExpiry(timeInterval: Int64) {
        userDefaults.set(timeInterval, forKey: Keys.userDetailExpiry)
    }

    /**
     * Clears the user detail expiry time from local storage.
     */
    func clearUserDetailExpiry() {
        userDefaults.removeObject(forKey: Keys.userDetailExpiry)
    }

    /**
     * Retrieves the attribute check expiry time from local storage.
     *
     * - Returns: The expiry time as an Int64 if available, otherwise nil.
     */
    func getAttributeCheckExpiry(storageKey: String) -> Int64? {
        let key = "\(storageKey)_\(Keys.attributeCheckExpiry)"
        let data = userDefaults.value(forKey: key)
        if let expiryTime = data as? Int64 {
            return expiryTime
        }
        return nil
    }
    /**
     * Saves the attribute check expiry time to local storage.
     *
     * - Parameter timeInterval: The expiry time to be saved.
     */
    func saveAttributeCheckExpiry(timeInterval: Int64, storageKey: String) {
        let key = "\(storageKey)_\(Keys.attributeCheckExpiry)"
        userDefaults.set(timeInterval, forKey: key)
    }

    /**
     * Clears the attribute check expiry time from local storage.
     */
    func clearAttributeCheckExpiry() {
        userDefaults.removeObject(forKey: Keys.attributeCheckExpiry)
    }

    /**
     * Fetch device ID is user Id is not provided
     * It creates and save the Device ID
     */
    func getDeviceId() -> String? {
        if let existingId = userDefaults.string(forKey: Keys.deviceIdKey) {
            return existingId
        } else {
             let vendorIdentifier = DeviceIDUtil.genrateDeviceId()
                userDefaults.set(vendorIdentifier, forKey: Keys.deviceIdKey)
                return vendorIdentifier
        }
    }

    /**
     * Retrieves the user detail from local storage if valid.
     *
     * - Returns: The GatewayService object if available and valid, otherwise nil.
     */
    func getUserDetail() -> GatewayService? {
        if !self.isCachedUserDetailValid() {
            return nil
        }

        if let gatewayData = userDefaults.data(forKey: Keys.userDetail) {
            let decoder = JSONDecoder()
            do {
                let gatewayResponse = try decoder.decode(GatewayService.self, from: gatewayData)
                return gatewayResponse
            } catch {
                LoggerService.log(level: .error, key: "STORED_DATA_ERROR", details: ["err": "\(error.localizedDescription)"])
            }
        }
        return nil
    }

    /**
     * Saves the user detail to local storage and updates the expiry time.
     *
     * - Parameter userDetail: The GatewayService object to be saved.
     */
    func saveUserDetail(userDetail: GatewayService) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(userDetail)
            userDefaults.set(data, forKey: Keys.userDetail)

            let timeExpiry = Date().currentTimeMillis() + Constants.LOCATION_EXPIRY
            self.saveUserDetailExpiry(timeInterval: timeExpiry)
        } catch {
            LoggerService.log(level: .error, key: "ERROR_STORING_DATA_IN_STORAGE", details: ["err": "\(error.localizedDescription)"])
        }
    }

    /**
     * Clears the user detail from local storage.
     */
    func clearUserDetail() {
        userDefaults.removeObject(forKey: Keys.userDetail)
    }

    /**
     * Retrieves the usage stats from local storage.
     *
     * - Returns: Dictionary if available and valid, otherwise nil.
     */
    func getUsageStats() -> [String: Any]? {
        guard let data = userDefaults.data(forKey: Keys.usageStats) else {
            return nil
        }
        do {
            let decodedData = try JSONSerialization.jsonObject(with: data, options: [])
            if let dict = decodedData as? [String: Any] {
                return dict
            }
        } catch {
            LoggerService.log(level: .error, key: "STORED_DATA_ERROR", details: ["err": "\(error.localizedDescription)"])
        }
        return nil
    }

    /**
     * Saves the usage stats to local storage.
     *
     * - Parameter data: Usage stats dictionary to be saved.
     */
    func setUsageStats(data: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            userDefaults.set(jsonData, forKey: Keys.usageStats)
        } catch {
            LoggerService.log(level: .error, key: "ERROR_STORING_DATA_IN_STORAGE", details: ["err": "\(error.localizedDescription)"])
        }
    }

    /**
     * Clears the usage stats from local storage.
     */
    func clearUsageStats() {
        userDefaults.removeObject(forKey: Keys.usageStats)
    }

    /**
     * Retrieves the attribute check result from local storage if valid.
     *
     * - Parameters:
     *   - featureKey: The key for the feature.
     *   - listId: The list identifier.
     *   - attribute: The attribute name.
     *   - userId: The user identifier.
     *   - customVariable: A flag indicating if a custom variable is used.
     * - Returns: The attribute check result as a Bool if available and valid, otherwise nil.
     */
    func getAttributeCheck(featureKey: String, listId: String, attribute: String, userId: String, customVariable: Bool) -> Bool? {
        if featureKey.isEmpty, listId.isEmpty, attribute.isEmpty, userId.isEmpty {
            LoggerService.log(level: .error, key: "STORED_DATA_ERROR", details: ["err": "Invalid data"])
            return nil
        }
        let storageKey = self.getStorageKeyForAttributeCheck(featureKey: featureKey, listId: listId, attribute: attribute, userId: userId, customVariable: customVariable)
        if !self.isCachedAttributeCheckValid(storageKey: storageKey) {
            return nil
        }
        if let data = userDefaults.dictionary(forKey: storageKey) {
            if let result = data["result"] as? Bool {
                return result
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    /**
     * Saves the attribute check result to local storage and updates the expiry time.
     *
     * - Parameters:
     *   - featureKey: The key for the feature.
     *   - listId: The list identifier.
     *   - attribute: The attribute name.
     *   - result: The result of the attribute check.
     *   - userId: The user identifier.
     *   - customVariable: A flag indicating if a custom variable is used.
     */
    func saveAttributeCheck(featureKey: String, listId: String, attribute: String, result: Bool, userId: String, customVariable: Bool) {
        if featureKey.isEmpty, listId.isEmpty, attribute.isEmpty, userId.isEmpty {
            LoggerService.log(level: .error, key: "ERROR_STORING_DATA_IN_STORAGE", details: ["err": "Invalid data"])
            return
        }

        let storageKey = self.getStorageKeyForAttributeCheck(featureKey: featureKey, listId: listId, attribute: attribute, userId: userId, customVariable: customVariable)
        let data: [String: Any] = ["featureKey": featureKey,
                                   "listId": listId,
                                   "attribute": attribute,
                                   "userId":userId,
                                   "result": result,
                                   "customVariable": customVariable]
        userDefaults.set(data, forKey: storageKey)

        let timeExpiry = Date().currentTimeMillis() + Constants.LIST_ATTRIBUTE_EXPIRY
        self.saveAttributeCheckExpiry(timeInterval: timeExpiry, storageKey: storageKey)
    }

    /**
     * Generates a storage key for attribute check based on the provided parameters.
     *
     * - Parameters:
     *   - featureKey: The key for the feature.
     *   - listId: The list identifier.
     *   - attribute: The attribute name.
     *   - userId: The user identifier.
     *   - customVariable: A flag indicating if a custom variable is used.
     * - Returns: A string representing the storage key.
     */
    func getStorageKeyForAttributeCheck(featureKey: String, listId: String, attribute: String, userId: String, customVariable: Bool) -> String {
        let keyDsl = customVariable ? "customVariable" : "vwoUserId"
        let storageKey = "\(featureKey)_\(userId)_\(listId)_\(keyDsl)_\(attribute))"
        return storageKey
    }

    /**
     * Checks if the cached attribute check is still valid based on expiry time.
     *
     * - Returns: A Bool indicating if the cached attribute check is valid.
     */
    func isCachedAttributeCheckValid(storageKey: String) -> Bool {
        let savedExpiryTime = self.getAttributeCheckExpiry(storageKey: storageKey)
        let now = Date().currentTimeMillis()
        if let expiryTime = savedExpiryTime {
            return now < expiryTime
        }
        return false
    }

    /**
     * Checks if the cached user detail is still valid based on expiry time.
     *
     * - Returns: A Bool indicating if the cached user detail is valid.
     */
    func isCachedUserDetailValid() -> Bool {
        let savedExpiryTime = self.getUserDetailExpiry()
        let now = Date().currentTimeMillis()
        if let expiryTime = savedExpiryTime {
            return now < expiryTime
        }
        return false
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
        userDefaults.removePersistentDomain(forName: Constants.SDK_USERDEFAULT_SUITE)
    }

    /**
     * Retrieves data from storage for a specific feature key and context.
     *
     * - Parameters:
     *   - featureKey: The key for the feature.
     *   - context: The context containing user information.
     * - Returns: A dictionary of stored data if available, otherwise nil.
     */
    private func getDataInStorage(featureKey: String?, context: VWOUserContext) -> [String: Any]? {
        guard let featureKey = featureKey else { return nil }
        guard let userId = context.id else { return nil }

        let storageKey = "\(featureKey)_\(userId)"
        if let connector = StorageConnectorProvider.shared.getStorageConnector() {
            if let data = connector.get(forKey:storageKey) {
                return data
            } else {
                return nil
            }
        }else{
            if let data = userDefaults.dictionary(forKey: storageKey) {
                return data
            } else {
                return nil
            }
        }
    }

    /**
     * Sets data in storage for a specific feature key and user ID.
     *
     * - Parameter data: A dictionary containing the data to be stored.
     */
    func setDataInStorage(data: [String: Any]) {
        guard let featureKey = data["featureKey"] as? String, let userId = data["userId"] as? String else {
            LoggerService.errorLog(key: "ERROR_STORING_DATA_IN_STORAGE",data:["err":"Invalid data"] ,debugData: ["an":ApiEnum.getFlag.rawValue])
            return
        }

        let rolloutKey = data["rolloutKey"] as? String
        let experimentKey = data["experimentKey"] as? String
        let rolloutVariationId = data["rolloutVariationId"] as? Int
        let experimentVariationId = data["experimentVariationId"] as? Int

        if let rolloutKey = rolloutKey, !rolloutKey.isEmpty, experimentKey == nil, rolloutVariationId == nil {
            LoggerService.errorLog(key: "ERROR_STORING_DATA_IN_STORAGE",data:["key": "Variation:(rolloutKey, experimentKey or rolloutVariationId)"] ,debugData: ["an":ApiEnum.getFlag.rawValue])
            return
        }

        if let experimentKey = experimentKey, !experimentKey.isEmpty, experimentVariationId == nil {
            LoggerService.errorLog(key: "ERROR_STORING_DATA_IN_STORAGE",data:["key":"Variation:(experimentKey or rolloutVariationId)"] ,debugData: ["an":ApiEnum.getFlag.rawValue])
            return
        }

        let storageKey = "\(featureKey)_\(userId)"
        if let connector = StorageConnectorProvider.shared.getStorageConnector() {
            connector.set( data, forKey: storageKey)
        }else{
            userDefaults.set(data, forKey: storageKey)
        }
    }

    /**
     * Retrieves a feature from storage for a specific feature key and context.
     *
     * - Parameters:
     *   - featureKey: The key for the feature.
     *   - context: The context containing user information.
     * - Returns: A dictionary of stored data if available, otherwise nil.
     */
    func getFeatureFromStorage(featureKey: String, context: VWOUserContext) -> [String : Any]? {
        return self.getDataInStorage(featureKey: featureKey, context: context)
    }

}
